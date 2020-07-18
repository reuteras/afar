Remove-Item -Force -Recurse 'C:\Run\Report\*'
Remove-Item -Force -Recurse 'C:\Run\lnk_report.zip'

Set-Location C:\Run
C:\Run\LECmd.exe -f "$args" --json "C:\Run\Report" --jsonpretty > C:\Run\Report\lnk-xml-stdout.txt
C:\Run\LECmd.exe -f "$args" > C:\Run\Report\lnk.txt

Add-Type -Assembly "System.IO.Compression.FileSystem";
[System.IO.Compression.ZipFile]::CreateFromDirectory("c:\Run\Report\", "c:\Run\lnk_report.zip");

