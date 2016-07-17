# AFAR

AFAR - Automatic File Analyze and Reporting is a script that takes a list of files as input and runs them through a couple of tests and generates a report that can be used as a starting point for further malware analyzes. This tool main usefulness is to automate malware analyzes. Tests are done in Virtual machines. At the moment it is only written to work with VMware [Fusion](https://www.vmware.com/products/fusion/) on Mac [OS X](https://www.apple.com/osx/). It uses three virtual machines for different tests. My setup is the following:

* [Debian](https://www.debian.org/) with [Cuckoo Sandbox](https://cuckoosandbox.org/). I use Cuckoo Sandbox 2.0-dev which uses [Volatility](http://www.volatilityfoundation.org/) and [Suricata](http://suricata-ids.org/). The VM is configured with my [cuckoo-tools](https://github.com/reuteras/cuckoo-tools) script.
* [REMnux](https://remnux.org/) with [SIFT](https://github.com/sans-dfir/sift-bootstrap) installed. The VM is installed with my [remnux-tools](https://github.com/reuteras/remnux-tools) script.
* [Windows 10](https://www.microsoft.com/en-us/windows/default.aspx) with [LECmd](https://github.com/EricZimmerman/LECmd).

Tools used by AFAR in REMnux includes but are not limited to:

* [Yara-Rules](https://github.com/Yara-Rules/rules)
* [bulk_extractor](http://www.forensicswiki.org/wiki/Bulk_extractor)
* [Density Scout](http://www.cert.at/downloads/software/densityscout_en.html)
* [peepdf](http://eternal-todo.com/tools/peepdf-pdf-analysis-tool#releases)
* [AnalyzePDF](https://github.com/hiddenillusion/AnalyzePDF)
* [PDF tools by Didier Stevens](http://blog.didierstevens.com/programs/pdf-tools/) includes pdfid.py, pdf-parser.py
* [oledump.py](http://blog.didierstevens.com/programs/oledump-py/)
* [packerid](http://handlers.sans.org/jclausing/packerid.py)
* [signsrch](http://aluigi.altervista.org/mytoolz.htm)
* [pescanner](https://code.google.com/p/malwarecookbook/source/browse/trunk/3/8/pescanner.py)
* [peframe](https://github.com/guelfoweb/peframe)
* [pedump](http://pedump.me/)
* [objdump](http://en.wikipedia.org/wiki/Objdump)
* [exescan.py](http://securityxploded.com/exe-scan.php)
* [olevba.py](https://bitbucket.org/decalage/oletools/wiki/olevba)
* [oleid.py](http://www.decalage.info/python/oletools)
* [olemeta.py](http://www.decalage.info/python/oletools)
* [oletimes.py](http://www.decalage.info/python/oletools)
* [officeparser.py](https://github.com/unixfreak0037/officeparser)
* [pyOLEScanner.py](https://github.com/Evilcry/PythonScripts/raw/master/)

## Background

I get lists with CSV files with malware stopped by anti virus and wanted to analyze the files. To do this I wrote a script to take this information and call a script written by a colleague. The next problem was that I know had a bunch of files that was flagged as malware. How to get more information about their characteristics since AV vendors usually are bad at writing technical descriptions of malware? I then submitted the files to Cuckoo and had to look through a page for each file submitted. Heres where AFAR comes in. It submits the suspicious files to Cuckoo and also does some analyzes in REMnux and Windows if available. Then you can take a cup or two of coffee and wait for the result which gives a one page overview of the files with links to more information.

## Warning

By default some of the tools will submit the files being analyzed to Virustotal and potentially other services. If you don't want this to happen please disconnect your computer from the internet during script execution. It's on my todo-list to control this with a command line option.

## Processing of input files

If you use the AFAR with three VMs as listed above the steps are as follow:

* Start Cuckoo and REMnux (if you know you will have a .lnk file and add the _-W_ option Windows is started to).
* Prepare files. This step unpacks zip files and creates a file structure under WORKDIR.
* Copy files to Cuckoo and REMnux and submit all files to Cuckoo.
* Depending of file type do different types of tests of the file in REMnux and Windows. Collect logs from each test.
* Wait for Cuckoo to finish. Remember to drink coffee during this step.
* Retrieve reports from Cuckoo and unpack them too the WORKDIR structure.
* Generate summary report.

## Installation and configuration

Checkout the code from Github and copy the default configuration to _config.cfg_(or use the -c switch if you have more then one configuration).

    git clone https://github.com/reuteras/afar.git
    cp config.cfg-default config.cfg
    $EDITOR config.cfg

I should update this section with more information about configuration that are needed in the different VMs. Some noteworthy changes that I remember are:

* Windows: Activate administrator account and set a password. Also change configuration to make it possible to run Powershell.
* Debian and REMnux. Make sure that the user used to login can do **sudo** without entering a password (NOPASSWD option in _/etc/sudoers_).

There are probably more changes needed and I will add them when I remember what I've changed that have an effect on AFAR.

## Usage

Since there are many changes in the code at the moment the best information about the program is to look at the built in help. Or use the force and read the code. At the moment the help output looks like this:

    ./afar.sh [-h] [-v] [-o] [-w] [-c config] [-C] [-R] [-W] [-Z] file1 ... fileN
        -c config       Load config file. Default is config.cfg.
        -h              Show help
        -o              Open summary when done
        -p              Paus before stopping and deleting VM
        -r              Run report generation again and exit
        -v              Verbose
        -w              Start Windows directly
        -Z              Remove WORKDIR without questions
        -C              Don't use Cuckoo
        -R              Don't use REMnux
        -W              Don't use Windows

A typical invocation for me is:

	./afar.sh -o -Z test/*

## Result

In your specified _WORKDIR_ you will get a folder per submitted file and extra folders if there are any zip-files since they are unpacked (tries with empty password and the passwords "virus" and "infected". The folders are numbered from 1 counting upwards. There is also a file named _index.html_ with the summary report. The folder cuckoo contains a text file with the last status from the Cuckoo Sandbox API. In each directory there is couple of files and directories. For a file that isn't a duplicate there is usually a minimum of the following:

* 0_report.txt
* 1_<filetype> - only created if there is a script for that file type
* 2_file/ - directory that contains the original file
* 3_cuckoo/ - Directory with the total Cuckoo report and other outputs for the file
* 4_cuckoo_report.html - Cuckoo report web page.
* 9_sha256.txt - File with the files sha256.

If the file is a duplicate the contents will be:

* 0_report.txt
* 2_file/
* 4_cuckoo_report.html@ - Link to the other files Cuckoo report
* 5_duplicate_of_10@ - The number (10 in this case) is a link do the duplicate that has been analyzed
* 6_duplicate - File indicates that this is a duplicate
* 9_sha256.txt

Depending on file type there will be other report files or directories present. I'm trying to follow a naming scheme where a file named _pdf-parser-f-w.txt_ indicates that the command **pdf-parser** was executed with the flags _-f -w_.

## Bugs

Probably. If you dare to use this script and find bugs please file a issue report at Github.

## TODO

* Look into the possibility to control what data are sent to the internet with a command line option to AFAR.
  - Full internet access as is the current standard. If you like to exit via VPN you can use that for all of your traffic.
  - Only send hashes to the internet (Virustotal). No access to the internet for Cuckoo.
  - No net
* Add support for Cuckoo's url scanning.
* Code cleanup and make sure the code is secure.
* Write a script that monitors the status of analyzes running in Cuckoo to make it possible to estimate when the report is finished.
* Look at the test executed on files. At the moment it's the result of a quick and dirty look through the REMnux documentation. Write scripts for more file types (jar, ps1 and more). Find test files for each type of file. The following sources are some that can be useful.
  - https://digital-forensics.sans.org/community/downloads/#howtos
  - https://remnux.org/
  - https://zeltser.com/remnux-malware-analysis-tips/
* Better reporting. Besides the file and signature parts from the Cuckoo Sandbox reports for each file the summary page only adds information about matches from Yara-Rules.
* More tools to look at
  - https://bitbucket.org/decalage/balbuzard/wiki/Home

