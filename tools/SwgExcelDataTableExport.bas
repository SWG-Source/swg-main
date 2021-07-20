Attribute VB_Name = "SwgExcelDataTableExport"
Sub DataTableExport()
   Dim DestFile As String
   Dim FileNum As Integer
   Dim ColumnCount As Long
   Dim RowCount As Long
   Dim LastRow As Integer
   LastRow = ActiveSheet.UsedRange.Rows.Count
   Dim LastCol As Integer
   LastCol = ActiveSheet.UsedRange.Columns.Count

   DestFile = InputBox("Enter the name of the data table source file with its extension (like skills.tab) to save as (note: if the file is open, use a different name then delete and replace it):", "SWG Data Table Export")
   FileNum = FreeFile()
   On Error Resume Next
   Open DestFile For Output As #FileNum
   If Err <> 0 Then
      MsgBox "Cannot open filename " & DestFile
      End
   End If
   On Error GoTo 0

   For RowCount = 1 To LastRow

      For ColumnCount = 1 To LastCol

         Print #FileNum, Selection.Cells(RowCount, _
         ColumnCount).Text;

         If ColumnCount = LastCol Then
            Print #FileNum,
         Else
            Print #FileNum, vbTab;
         End If
         
      Next ColumnCount
      
   Next RowCount

   
   Close #FileNum
End Sub
