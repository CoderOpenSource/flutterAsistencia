import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mapas_api/widgets/stripe/pagos_online.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

Map<String, String> tiposPagoMap = {
  'paypal': 'PayPal',
  'transferencia': 'Transferencia',
  'efectivo': 'Efectivo',
  'online': 'Pagos en Línea Visa',
};

class TipoPago {
  final int id;
  final String nombre;
  final String? imagenUrl;

  TipoPago({required this.id, required this.nombre, this.imagenUrl});

  factory TipoPago.fromJson(Map<String, dynamic> json) {
    return TipoPago(
      id: json['id'],
      nombre: json['nombre'],
      imagenUrl: json['imagen_qr'],
    );
  }
}

class PantallaPago extends StatefulWidget {
  const PantallaPago({super.key});

  @override
  _PantallaPagoState createState() => _PantallaPagoState();
}

class _PantallaPagoState extends State<PantallaPago> {
  int? usuario;
  List<TipoPago> _tiposPago = [];
  Map<String, dynamic> userData = {};
  TipoPago? selectedPaymentMethod;
  List<Map<String, dynamic>> displayedProducts = [];
  bool isLoading = true;
  int? cartId;
  @override
  void initState() {
    super.initState();
    _cargarTiposPago();
    _fetchUserData().then((data) {
      setState(() {
        userData = data;
      });
    }).catchError((error) {
      // Puedes manejar errores aquí si lo deseas
      print('Error fetching user data: $error');
    });
    fetchCartItems();
  }

  Future<void> generatePdf(BuildContext context) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Datos del Pedido', style: const pw.TextStyle(fontSize: 24)),
                pw.Divider(),
                pw.Text('Nombre: ${userData['first_name']}'),
                pw.Text('Dirección: ${userData['address']}'),
                pw.Divider(),
                ...displayedProducts.map(
                  (product) {
                    final precio = double.parse(
                        product['productodetalle_detail']['producto']['precio']
                            .toString());
                    final descuento = double.parse(
                        product['productodetalle_detail']['producto']
                                ['descuento_porcentaje']
                            .toString());
                    final discountedPrice =
                        precio - (precio * (descuento / 100));

                    return pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                    product['productodetalle_detail']
                                            ['producto']['nombre']
                                        .replaceAll('Ã±', 'ñ'),
                                    style: const pw.TextStyle(fontSize: 18)),
                                if (descuento > 0)
                                  pw.Text('Antes: Bs$precio',
                                      style: const pw.TextStyle(
                                          decoration:
                                              pw.TextDecoration.lineThrough)),
                                pw.Text(
                                  descuento > 0
                                      ? 'Ahora: Bs$discountedPrice'
                                      : 'Precio: Bs$precio',
                                  style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.Text('Cantidad: ${product['cantidad']}',
                                    style: const pw.TextStyle(fontSize: 16)),
                              ]),
                        ]);
                  },
                ).toList(),
                pw.Divider(),
                pw.Text(
                    'Total a Pagar: Bs${calcularTotal().toStringAsFixed(2)}',
                    style: pw.TextStyle(
                        fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.Text(
                    'Método de pago: ${selectedPaymentMethod?.nombre ?? 'No seleccionado'}',
                    style: const pw.TextStyle(fontSize: 16)),
              ]);
        },
      ),
    );

    // Guardar el PDF en un archivo y mostrarlo
    final output = await getTemporaryDirectory();
    final file = File("${output.path}/Pedido.pdf");
    await file.writeAsBytes(await pdf.save());
    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Future<void> fetchCartItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = int.parse(prefs.getString('userId') ?? '0');
      usuario = int.parse(prefs.getString('userId') ?? '0');
      print('usuario logeado $userId');
      final response = await http
          .get(Uri.parse('http://137.184.190.92/transacciones/carritos/'));
      final data = json.decode(response.body) as List;

      final userCart = data.firstWhere(
          (cart) => cart['usuario'] == userId && cart['disponible'] == true,
          orElse: () => null);

      if (userCart != null) {
        setState(() {
          displayedProducts =
              List<Map<String, dynamic>>.from(userCart['productos_detalle']);
          cartId = userCart['id'];
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (error) {
      print('Error al obtener los productos del carrito: $error');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _cargarTiposPago() async {
    final uri = Uri.parse('http://137.184.190.92/transacciones/tipos_pago/');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List<dynamic> tiposPagoJson = json.decode(response.body);
      setState(() {
        _tiposPago =
            tiposPagoJson.map((json) => TipoPago.fromJson(json)).toList();
      });
    } else {
      // Manejo de errores
      print('Solicitud fallida con estado: ${response.statusCode}.');
    }
  }

  Future<Map<String, dynamic>> _fetchUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    print('$userId--------------------------------------');
    if (userId == null) {
      throw Exception("User ID not found");
    }
    final response = await http
        .get(Uri.parse('http://137.184.190.92/users/usuarios-cliente/$userId'));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load user data');
    }
  }

  @override
  Widget build(BuildContext context) {
    double cartTotal = calcularTotal();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E272E),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Datos del Pedido',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: ListView(
          children: [
            const SizedBox(
              height: 10,
            ),
            // Información del usuario editable
            if (userData.isNotEmpty) ...[
              TextFormField(
                initialValue: userData['first_name'],
                decoration: InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                onChanged: (value) {
                  // Actualizar el nombre del usuario si es necesario
                  userData['first_name'] = value;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: userData['address'],
                decoration: InputDecoration(
                  labelText: 'Dirección',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                onChanged: (value) {
                  // Actualizar la dirección del usuario si es necesario
                  userData['address'] = value;
                },
              ),
              const SizedBox(height: 20),
              const Divider(),
            ],

            displayedProducts.isEmpty
                ? const Center(
                    child: Text(
                      'Carrito vacío',
                      style: TextStyle(
                        fontSize: 24.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  )
                : Column(
                    children: displayedProducts.map((product) {
                      double precio = double.parse(
                          product['productodetalle_detail']['producto']
                                  ['precio']
                              .toString());
                      double descuento = double.parse(
                          product['productodetalle_detail']['producto']
                                  ['descuento_porcentaje']
                              .toString());
                      double discountedPrice =
                          precio - (precio * (descuento / 100));

                      return Card(
                        elevation: 4.0,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 10.0, vertical: 6.0),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: <Widget>[
                              // Imagen del producto
                              SizedBox(
                                width: 100,
                                height: 100,
                                child: Image.network(
                                  product['productodetalle_detail']['producto']
                                      ['imagenes'][0]['ruta_imagen'],
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 10.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product['productodetalle_detail']
                                                ['producto']['nombre']
                                            .replaceAll('Ã±', 'ñ'),
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      if (descuento > 0)
                                        Text(
                                          'Antes: Bs$precio',
                                          style: const TextStyle(
                                            decoration:
                                                TextDecoration.lineThrough,
                                          ),
                                        ),
                                      Text(
                                        descuento > 0
                                            ? 'Ahora: Bs$discountedPrice'
                                            : 'Precio: Bs$precio',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: descuento > 0
                                              ? const Color(0xFF1E272E)
                                              : Colors.black,
                                        ),
                                      ),
                                      Text(
                                        'Cantidad: ${product['cantidad']}',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
            if (displayedProducts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const Text(
                      'Total a Pagar:',
                      style: TextStyle(
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Bs${cartTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold,
                        color: Color(
                            0xFF1E272E), // o cualquier otro color que prefieras
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            // Título para métodos de pago
            if (_tiposPago.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Selecciona un método de pago:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              DropdownButton<TipoPago>(
                value: selectedPaymentMethod,
                hint: const Text('Método de pago'),
                isExpanded: true,
                items: _tiposPago
                    .map<DropdownMenuItem<TipoPago>>((TipoPago method) {
                  return DropdownMenuItem<TipoPago>(
                    value: method,
                    child: Row(
                      children: [
                        if (method.imagenUrl != null)
                          Image.network(
                            method.imagenUrl!,
                            width: 40, // Increased size for better visibility
                            height: 40,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.error,
                                color: Colors.red,
                              ); // Icon if image fails to load
                            },
                          ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            tiposPagoMap[method.nombre] ?? method.nombre,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (TipoPago? newValue) {
                  setState(() {
                    selectedPaymentMethod = newValue;
                    print(selectedPaymentMethod!.nombre);
                  });
                },
              ),
              const SizedBox(height: 20),
            ],

            // Botón de confirmación
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E272E),
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onPressed: () {
                // Validación de la selección del método de pago y de los datos del usuario
                if (selectedPaymentMethod != null &&
                    userData['first_name'].isNotEmpty &&
                    userData['address'].isNotEmpty) {
                  if (selectedPaymentMethod!.nombre == 'online') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => HomePage(
                                total: cartTotal.toInt(),
                                usuario: usuario.toString(),
                                carritoId: cartId.toString(),
                                tipoPagoId: 2.toString(),
                              )),
                    );
                  }
                  // Aquí manejas el evento de clic del botón de confirmar pago
                } else {
                  // Mostrar mensaje de error si es necesario
                }
              },
              child: const Text('Confirmar Pago',
                  style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  double calcularTotal() {
    double total = 0.0;
    for (var product in displayedProducts) {
      double precio = double.parse(
          product['productodetalle_detail']['producto']['precio'].toString());
      double descuento = double.parse(product['productodetalle_detail']
              ['producto']['descuento_porcentaje']
          .toString());
      int cantidad = int.parse(product['cantidad'].toString());
      final discountedPrice = precio - (precio * (descuento / 100));
      total += discountedPrice * cantidad; // Multiplicamos por la cantidad aquí
    }
    return total;
  }
}
