import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_credit_card/flutter_credit_card.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:mapas_api/blocs/pagar/pagar_bloc.dart';
import 'package:mapas_api/helpers/helpers.dart';
import 'package:mapas_api/main.dart';
import 'package:mapas_api/services/stripe_service.dart';
import 'package:mapas_api/helpers/tarjeta.dart';
import 'package:mapas_api/widgets/stripe/tarjeta_pago.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class HomePage extends StatefulWidget {
  final int total;
  final String usuario;
  final String carritoId;
  final String tipoPagoId;

  const HomePage({
    super.key,
    required this.total,
    required this.usuario,
    required this.carritoId,
    required this.tipoPagoId,
  });

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final StripeService stripeService = StripeService();
  bool done = false;
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
    Stripe.publishableKey =
        'pk_test_51OM6g0A7qrAo0IhR3dbWDmmwmpyZ6fu5WcwDQ9kSNglvbcqlPKy4xXSlwltVkGOkQgWh12T7bFJgjCQq3B7cGaFV007JonVDPp';
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
                pw.Text('Método de pago: Pago en Linea Visa',
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

  Map<String, dynamic>? paymentIntent;
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

  Future<void> makePayment(int total) async {
    try {
      paymentIntent = await createPaymentIntent(total);

      var gpay = const PaymentSheetGooglePay(
        merchantCountryCode: "US",
        currencyCode: "USD",
        testEnv: true,
      );
      await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: paymentIntent!["client_secret"],
        style: ThemeMode.dark,
        merchantDisplayName: "Prueba",
        googlePay: gpay,
      ));

      await displayPaymentSheet();
    } catch (e) {
      print('Error en makePayment: $e');
    }
  }

  Future<void> displayPaymentSheet() async {
    try {
      await Stripe.instance.presentPaymentSheet();
      print("DONE");
      setState(() {
        done = true;
      });
      realizarTransaccion();
      actualizarCarrito(widget.carritoId, false);
    } catch (e) {
      setState(() {
        done = false;
      });
      print('FAILED');
    }
  }

  createPaymentIntent(int total) async {
    try {
      String monto = (total * 100).toString();
      Map<String, dynamic> body = {
        "amount":
            monto, // aqui es el monto a pagar por el objeto, para que ingreses el monto de cada juguete ponle un parametro
        "currency": "USD", //en el void makePayment
      };
      http.Response response = await http.post(
        Uri.parse("https://api.stripe.com/v1/payment_intents"),
        body: body,
        headers: {
          "Authorization":
              "Bearer sk_test_51OM6g0A7qrAo0IhR79BHknFXkoeVL7M3yF9UYYnRlTEbGLQhc90La5scbYs2LAkHbh6dYQCw8CbqsTgNAgYvLBNn00I1QqzLDj",
        },
      );
      print(response.body);
      return json.decode(response.body);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> realizarTransaccion() async {
    final uri = Uri.parse('http://137.184.190.92/transacciones/transacciones/');
    final headers = {'Content-Type': 'application/json'};
    final body = json.encode({
      'usuario': widget.usuario,
      'carrito': widget.carritoId,
      'tipo_pago': widget.tipoPagoId,
    });

    final response = await http.post(uri, headers: headers, body: body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      // La transacción fue creada exitosamente
      print('Transacción realizada con éxito');
    } else {
      // Si la API no devuelve un estado exitoso, se maneja el error
      print('Error al realizar la transacción: ${response.statusCode}');
      print('Razón: ${response.body}');
    }
  }

  Future<void> actualizarCarrito(String carritoId, bool disponible) async {
    try {
      print('Estoy aqui');
      final response = await http.patch(
        Uri.parse('http://137.184.190.92/transacciones/carritos/$carritoId/'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'disponible': disponible,
        }),
      );

      if (response.statusCode == 200) {
        print('Carrito actualizado con éxito');
      } else {
        print('Error al actualizar el carrito: ${response.statusCode}');
        print('Respuesta: ${response.body}');
      }
    } catch (e) {
      print('Excepción al actualizar el carrito: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // ignore: close_sinks

    Stripe.publishableKey =
        'pk_test_51OM6g0A7qrAo0IhR3dbWDmmwmpyZ6fu5WcwDQ9kSNglvbcqlPKy4xXSlwltVkGOkQgWh12T7bFJgjCQq3B7cGaFV007JonVDPp';

    return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E272E),
          title: const Text('Paga con Stripe '),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                // Crear un nuevo controlador de edición de tarjeta
                final cardEditController = CardEditController();

                // Mostrar diálogo para agregar tarjeta
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Agregar tarjeta'),
                      content: SizedBox(
                        width: MediaQuery.of(context).size.width *
                            1, // Ajusta el ancho al 90% del ancho de pantalla
                        child: SingleChildScrollView(
                          child: ListBody(
                            children: <Widget>[
                              CardField(
                                controller: cardEditController,
                                onCardChanged: (card) {
                                  // Puedes manejar los cambios en la tarjeta aquí
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      actions: <Widget>[
                        TextButton(
                          child: const Text('Cancelar'),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                        TextButton(
                          child: const Text('Guardar'),
                          onPressed: () {
                            print(cardEditController.details);
                            agregarNuevaTarjeta(
                                cardNumber: cardEditController.details.last4!,
                                brand: cardEditController.details.brand!,
                                expiracyDate:
                                    '${cardEditController.details.expiryMonth}/${cardEditController.details.expiryYear}',
                                cvv: 123.toString(),
                                cardHolderName: 'MOSITO');
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            )
          ],
        ),
        body: Stack(
          children: [
            Positioned(
              width: size.width,
              height: size.height,
              top: 200,
              child: PageView.builder(
                  controller: PageController(viewportFraction: 0.9),
                  physics: const BouncingScrollPhysics(),
                  itemCount: tarjetas.length,
                  itemBuilder: (_, i) {
                    final tarjeta = tarjetas[i];

                    return GestureDetector(
                      onTap: () {
                        BlocProvider.of<PagarBloc>(context)
                            .add(OnSeleccionarTarjeta(tarjeta));
                        Navigator.push(context,
                            navegarFadeIn(context, const TarjetaPage()));
                      },
                      child: Hero(
                        tag: tarjeta.cardNumber,
                        child: CreditCardWidget(
                          cardNumber: tarjeta.cardNumberHidden,
                          expiryDate: tarjeta.expiracyDate,
                          cardHolderName: tarjeta.cardHolderName,
                          cvvCode: tarjeta.cvv,
                          showBackView: false,
                          onCreditCardWidgetChange: (CreditCardBrand) {},
                        ),
                      ),
                    );
                  }),
            ),
            Positioned(
              bottom: 0,
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.center, // Ajusta esto según sea necesario
                children: [
                  // Aquí añades tu nuevo widget a la izquierda
                  Text(
                    'Monto a Pagar: ${widget.total}',
                    style: const TextStyle(
                      color: Color(0xFF1E272E),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(
                    width: 20,
                  ),

                  // Tu MaterialButton existente
                  MaterialButton(
                    onPressed: () async {
                      await makePayment(widget.total);

                      if (done) {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text("Compra realizada con éxito"),
                              content: const Text(
                                  "Tu compra ha sido realizada exitosamente."),
                              actions: <Widget>[
                                TextButton(
                                  child: const Row(
                                    mainAxisSize: MainAxisSize
                                        .min, // Para que el botón sea del tamaño de su contenido
                                    children: <Widget>[
                                      Icon(
                                          Icons.download), // Ícono de descargar
                                      SizedBox(
                                          width:
                                              8), // Espaciado entre ícono y texto
                                      Text("Descargar"), // Texto del botón
                                    ],
                                  ),
                                  onPressed: () async {
                                    // Aquí puedes incluir la lógica para descargar el archivo o lo que necesites
                                    generatePdf(context);
                                  },
                                ),
                                TextButton(
                                  child: const Text("OK"),
                                  onPressed: () {
                                    // Cierra el modal y redirige al inicio, eliminando toda la pila de navegación
                                    Navigator.of(context)
                                        .pop(); // Cierra el modal
                                    Navigator.of(context).pushAndRemoveUntil(
                                      MaterialPageRoute(
                                          builder: (context) => const MyApp()),
                                      (Route<dynamic> route) =>
                                          false, // Esto elimina todas las rutas anteriores
                                    );
                                  },
                                ),
                              ],
                            );
                          },
                        );
                      }
                    },
                    height: 45,
                    minWidth: 150,
                    shape: const StadiumBorder(),
                    elevation: 0,
                    color: Colors.black,
                    child: Row(
                      mainAxisSize: MainAxisSize
                          .min, // para asegurar que el Row se ajuste al tamaño de sus hijos
                      children: [
                        Icon(
                          Platform.isAndroid
                              ? FontAwesomeIcons.google
                              : FontAwesomeIcons.apple,
                          color: Colors.white,
                        ),
                        const Text(' Pagar',
                            style:
                                TextStyle(color: Colors.white, fontSize: 22)),
                      ],
                    ),
                  ),
                ],
              ),
            )
          ],
        ));
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
