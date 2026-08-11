# U-Print

U-Print provides a command-line model of printers and print jobs that are
available through the local Windows printing system.

## Language

**Printer**:
A printer that is installed in the local Windows printing system.
_Avoid_: Device, endpoint

**Print job**:
A spooler record for a document that was sent to one printer.
_Avoid_: Print, submission

**Queue**:
The current set of print jobs for one printer.
_Avoid_: Job list

**Submission**:
The transfer of a document to a print engine without an observed error. A
submission does not confirm physical output.
_Avoid_: Printed, completed

**Universal Print submission**:
A submission to a printer whose installed driver identifies it as a Microsoft
Universal Print printer.
_Avoid_: Cloud print, printed
