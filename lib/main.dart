import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'dart:math';

void main() {
  runApp(ReceiptPrinterApp());
}

class ReceiptPrinterApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluetooth Receipt Printer',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: ReceiptPrinterScreen(),
    );
  }
}

class ReceiptPrinterScreen extends StatefulWidget {
  @override
  _ReceiptPrinterScreenState createState() => _ReceiptPrinterScreenState();
}

class _ReceiptPrinterScreenState extends State<ReceiptPrinterScreen> {
  List<BluetoothInfo>? _pairedPrinters = [];
  String? _connectedPrinter;
  bool _isFetchingDevices = false;
  bool _isConnected = false;
  bool _isPrinterSelected = false;

  // Form fields for receipt data
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _businessPhoneController = TextEditingController();
  final TextEditingController _businessLocationController = TextEditingController();
  
  final TextEditingController _driverNameController = TextEditingController();
  final TextEditingController _carNoController = TextEditingController();
  final TextEditingController _fromLocationController = TextEditingController();
  final TextEditingController _toLocationController = TextEditingController();
  final TextEditingController _passengersController = TextEditingController();
  final TextEditingController _totalPriceController = TextEditingController();

  // Invoice number and date
  String? _invoiceNumber; // Store generated invoice number
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchPairedPrinters();
    // Generate the invoice number on initialization
    _generateInvoiceNumber();
  }

  void _generateInvoiceNumber() {
    String date = "${_selectedDate.day}";
    String month = ["J1", "F2", "M3", "A4", "M5", "J6", "J7", "A8", "S9", "O8", "N10", "D12"][_selectedDate.month - 1];
    int randomNum = Random().nextInt(1000); // Generate a random number between 0 and 999
    setState(() {
      _invoiceNumber = "$date$month${randomNum.toString().padLeft(3, '0')}"; // Format: date-month-randomNumber
       print("Generated Invoice Number: $_invoiceNumber"); // Log to terminal
    });
  }


  // Fetch paired printers
  Future<void> _fetchPairedPrinters() async {
    setState(() {
      _isFetchingDevices = true;
    });

    try {
      List<BluetoothInfo> devices = await PrintBluetoothThermal.pairedBluetooths;

      setState(() {
        _pairedPrinters = devices;
      });
    } catch (e) {
      setState(() {
        _connectedPrinter = "Error fetching devices: $e";
      });
    } finally {
      setState(() {
        _isFetchingDevices = false;
      });
    }
  }

  // Connect to the selected printer
  Future<void> _connectToPrinter(BluetoothInfo printer) async {
    bool isConnected = await PrintBluetoothThermal.connect(macPrinterAddress: printer.macAdress);
    if (isConnected) {
      setState(() {
        _connectedPrinter = printer.name;
        _isConnected = true;
        _isPrinterSelected = true; // Mark printer as selected
      });
    } else {
      setState(() {
        _connectedPrinter = "Failed to connect to ${printer.name}";
        _isConnected = false;
        _isPrinterSelected = false;
      });
    }
  }

  // Disconnect from the printer
  Future<void> _disconnectPrinter() async {
    await PrintBluetoothThermal.disconnect;
    setState(() {
      _connectedPrinter = null;
      _isConnected = false;
      _isPrinterSelected = false; // Reset printer selection
    });
  }

  // Print the receipt
  Future<void> _printReceipt() async {
    if (!_isConnected) {
      print("No printer connected!");
      return;
    }

    List<int> bytes = [];
    CapabilityProfile profile = await CapabilityProfile.load();
    Generator generator = Generator(PaperSize.mm58, profile); // For a 58mm printer

    // Prepare receipt data with business details
    bytes += generator.text(
      "${_businessNameController.text}",
      styles: const PosStyles(align: PosAlign.center, bold: true, underline: true),
      linesAfter: 1,
    );

    bytes += generator.text(
      "Phone: ${_businessPhoneController.text}\nLocation: ${_businessLocationController.text}",
      styles: const PosStyles(align: PosAlign.center),
      linesAfter: 1,
    );

    bytes += generator.text(
      "Invoice No. $_invoiceNumber\nTaxi services\n${_selectedDate.toLocal().toString().split(' ')[0]}",
      styles: const PosStyles(align: PosAlign.center, bold: true),
      linesAfter: 1,
    );

    bytes += generator.text(
      "Driver's Name: ${_driverNameController.text}\nCar No: ${_carNoController.text}",
      styles: const PosStyles(align: PosAlign.left),
      linesAfter: 1,
    );

    bytes += generator.text(
      "From: ${_fromLocationController.text}\nTo: ${_toLocationController.text}\nPassengers: ${_passengersController.text}",
      styles: const PosStyles(align: PosAlign.left),
      linesAfter: 1,
    );

    bytes += generator.hr();

    bytes += generator.text(
      "Total Price: ${_totalPriceController.text}\nPayment: Cash",
      styles: const PosStyles(align: PosAlign.left, bold: true),
      linesAfter: 1,
    );

    bytes += generator.text(
      "Thank you for riding with us!",
      styles: const PosStyles(align: PosAlign.center),
      linesAfter: 2,
    );

    await PrintBluetoothThermal.writeBytes(bytes);
    
    await PrintBluetoothThermal.disconnect;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Receipt Printer"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Connected Printer: ${_connectedPrinter ?? "None"}",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: 16),

              // Display paired printers list only if no printer is selected
              if (!_isPrinterSelected) ...[
                if (_isFetchingDevices)
                  CircularProgressIndicator()
                else if (_pairedPrinters != null && _pairedPrinters!.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Select a Printer to Connect:",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: Column(
                          children: _pairedPrinters!
                              .map((printer) => ListTile(
                                    title: Text(printer.name),
                                    subtitle: Text(printer.macAdress),
                                    onTap: () => _connectToPrinter(printer),
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                  )
                else
                  const Text("No paired devices found."),
              ],

              // Show input fields for receipt data after a printer is selected
              if (_isPrinterSelected) ...[
                const Text(
                  "Enter Business Details:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),

                // Input fields for business details
                TextField(
                  controller: _businessNameController,
                  decoration: InputDecoration(labelText: "Business Name"),
                ),
                TextField(
                  controller: _businessPhoneController,
                  decoration: InputDecoration(labelText: "Business Phone"),
                  keyboardType: TextInputType.phone,
                ),
                TextField(
                  controller: _businessLocationController,
                  decoration: InputDecoration(labelText: "Business Location"),
                ),

                const SizedBox(height: 16),

                const Text(
                  "Enter Receipt Data:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),

                // Input fields for receipt data
                TextField(
                  controller: _driverNameController,
                  decoration: InputDecoration(labelText: "Driver's Name"),
                ),
                TextField(
                  controller: _carNoController,
                  decoration: InputDecoration(labelText: "Car Number"),
                ),
                TextField(
                  controller: _fromLocationController,
                  decoration: InputDecoration(labelText: "From Location"),
                ),
                TextField(
                  controller: _toLocationController,
                  decoration: InputDecoration(labelText: "To Location"),
                ),
                TextField(
                  controller: _passengersController,
                  decoration: InputDecoration(labelText: "Number of Passengers"),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: _totalPriceController,
                  decoration: InputDecoration(labelText: "Total Price"),
                  keyboardType: TextInputType.number,
                ),

                // Date Picker for selecting date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Receipt Date:", style: TextStyle(fontWeight: FontWeight.bold)),
                    ElevatedButton(
                      onPressed: _selectDate,
                      child: const Text("Select Date"),
                    ),
                  ],
                ),

                SizedBox(height: 16),

                // Print button
                ElevatedButton(
                  onPressed: _isConnected ? _printReceipt : null,
                  child: const Text("Print Receipt"),
                ),

                SizedBox(height: 16),

                // Disconnect button
                ElevatedButton(
                  onPressed: _isConnected ? _disconnectPrinter : null,
                  child: const Text("Disconnect Printer"),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    // Show date picker dialog and update selected date
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000), // Set your desired start date here
      lastDate: DateTime.now(), // Today or any future date you want to allow
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked; // Update selected date with user choice
        _generateInvoiceNumber(); // Regenerate invoice number on date change if needed.
      });
    }
  }
}
