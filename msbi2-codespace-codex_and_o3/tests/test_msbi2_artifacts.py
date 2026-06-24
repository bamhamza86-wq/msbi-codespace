import json
import pathlib
import unittest
import xml.etree.ElementTree as ET


PROJECT = pathlib.Path(__file__).resolve().parents[1]


class Msbi2ArtifactTests(unittest.TestCase):
    def test_expected_files_exist(self):
        expected = [
            "compose.yaml",
            "sql/00_create_dw.sql",
            "sql/20_etl_delta_procs.sql",
            "sql/90_validation.sql",
            "ssis/LoadDWDelta.biml",
            "ssas/model.bim",
            "ssrs/SalesByRegion.rdl",
            "ssrs/MonthlySales.rdl",
            "ssrs/TopCustomers.rdl",
        ]
        for relative in expected:
            self.assertTrue((PROJECT / relative).is_file(), relative)

    def test_sql_defines_dw_star_schema_and_delta(self):
        sql = "\n".join(path.read_text(encoding="utf-8") for path in sorted((PROJECT / "sql").glob("*.sql")))
        required_fragments = [
            "CREATE DATABASE [DW]",
            "CREATE SCHEMA dw",
            "source.CustomerChanges",
            "stg.CustomerDelta",
            "dw.DimCustomer",
            "dw.DimProduct",
            "dw.DimRegion",
            "dw.DimDate",
            "dw.FactSales",
            "etl.Watermark",
            "CREATE OR ALTER PROCEDURE etl.usp_LoadDeltaAll",
            "MERGE dw.FactSales",
            "rpt.vSalesByRegion",
            "MSBI2_VALIDATION_OK",
        ]
        for fragment in required_fragments:
            self.assertIn(fragment, sql)

    def test_ssis_biml_runs_delta_procedure(self):
        tree = ET.parse(PROJECT / "ssis" / "LoadDWDelta.biml")
        root_text = ET.tostring(tree.getroot(), encoding="unicode")
        self.assertIn("LoadDWDelta", root_text)
        self.assertIn("etl.usp_LoadDeltaAll", root_text)
        self.assertIn("ExecuteSQL", root_text)

    def test_ssas_model_contains_star_schema(self):
        model = json.loads((PROJECT / "ssas" / "model.bim").read_text(encoding="utf-8"))
        tables = {table["name"] for table in model["model"]["tables"]}
        self.assertEqual(
            {"Fact Sales", "Dim Date", "Dim Customer", "Dim Product", "Dim Region"},
            tables,
        )
        relationships = {rel["name"] for rel in model["model"]["relationships"]}
        self.assertEqual(
            {
                "FactSales_DimDate",
                "FactSales_DimCustomer",
                "FactSales_DimProduct",
                "FactSales_DimRegion",
            },
            relationships,
        )

    def test_ssrs_reports_query_reporting_views_and_display_fields(self):
        expected_views = {
            "SalesByRegion.rdl": "rpt.vSalesByRegion",
            "MonthlySales.rdl": "rpt.vMonthlySales",
            "TopCustomers.rdl": "rpt.vTopCustomers",
        }
        for report_name, view_name in expected_views.items():
            report = PROJECT / "ssrs" / report_name
            ET.parse(report)
            xml_text = report.read_text(encoding="utf-8")
            self.assertIn(view_name, xml_text)
            self.assertIn("<Tablix", xml_text)
            self.assertIn("=Fields!", xml_text)


if __name__ == "__main__":
    unittest.main()
