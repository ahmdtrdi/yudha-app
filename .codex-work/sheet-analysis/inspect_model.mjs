import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const filePath = "C:/Users/User/Downloads/YUDHA_Financial_Model_v5_Monthly_Only.xlsx";
const input = await FileBlob.load(filePath);
const workbook = await SpreadsheetFile.importXlsx(input);

for (const [sheetId, range] of [
  ["Monthly Model", "A65:C78"],
  ["Monthly Model", "A93:C102"],
  ["Monthly Model", "A103:C109"],
]) {
  const result = await workbook.inspect({
    kind: "table,formula",
    sheetId,
    range,
    include: "values,formulas",
    tableMaxRows: 120,
    tableMaxCols: 30,
    tableMaxCellChars: 180,
    maxChars: 40000,
    options: { maxResults: 400 },
  });
  console.log(`RANGE ${sheetId}!${range}`);
  console.log(result.ndjson);
}
