import 'package:mapas_api/main.dart';
import 'package:mapas_api/widgets/pagos_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<Map<String, dynamic>> displayedProducts = [];
  bool isLoading = true;
  int? cartId;
  @override
  void initState() {
    super.initState();
    fetchCartItems();
  }

  Future<void> fetchCartItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = int.parse(prefs.getString('userId') ?? '0');
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

  Future<void> updateCart(int cartId) async {
    final initialProductIds =
        displayedProducts.map((product) => product['id']).toSet();

    final updatedProducts = displayedProducts.map((product) {
      return {
        "id": product['id'],
        "productodetalle": product['productodetalle_id'],
        "productodetalle_id": product['productodetalle_id'],
        "cantidad": product['cantidad'],
        "carrito": cartId,
      };
    }).toList();

    final prefs = await SharedPreferences.getInstance();
    final userId = int.parse(prefs.getString('userId') ?? '0');

    final response = await http.put(
      Uri.parse('http://137.184.190.92/transacciones/carritos/$cartId/'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, dynamic>{
        'carritoproductodetalle_set': updatedProducts,
        'usuario': userId,
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      appBar: AppBar(
          backgroundColor: const Color(0xFF1E272E),
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Row(
              mainAxisAlignment:
                  MainAxisAlignment.center, // Esto centrará tus botones
              mainAxisSize:
                  MainAxisSize.max, // Esto toma el espacio mínimo necesario
              children: [
                Text(
                  'Mi Carritto ',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ])),
      body: displayedProducts.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center, // Centra verticalmente
                children: <Widget>[
                  Icon(
                    Icons.shopping_cart,
                    size: 100, // Ajusta el tamaño como prefieras
                    color: Colors.white,
                  ),
                  Text(
                    'Carrito vacío',
                    style: TextStyle(
                      fontSize: 30, // Ajusta el tamaño de texto como prefieras
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: displayedProducts.length,
              itemBuilder: (context, index) {
                double precio = double.parse(displayedProducts[index]
                        ['productodetalle_detail']['producto']['precio']
                    .toString());
                double descuento = double.parse(displayedProducts[index]
                            ['productodetalle_detail']['producto']
                        ['descuento_porcentaje']
                    .toString());
                final discountedPrice = precio - (precio * (descuento / 100));

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
                            displayedProducts[index]['productodetalle_detail']
                                ['producto']['imagenes'][0]['ruta_imagen'],
                            fit: BoxFit.cover,
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 10.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayedProducts[index]
                                              ['productodetalle_detail']
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
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                Text(
                                  descuento > 0
                                      ? 'Ahora: Bs$discountedPrice'
                                      : 'Precio: Bs$precio',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: descuento > 0
                                        ? Colors.red
                                        : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Cantidad: ${displayedProducts[index]['cantidad']}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Column(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.add_circle,
                                  color: Colors.green),
                              onPressed: () {
                                setState(() {
                                  displayedProducts[index]['cantidad']++;
                                  // Aquí tu lógica para actualizar el carrito
                                });
                                if (cartId != null) {
                                  updateCart(cartId!);
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle,
                                  color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  if (displayedProducts[index]['cantidad'] >
                                      1) {
                                    displayedProducts[index]['cantidad']--;
                                    // Aquí tu lógica para actualizar el carrito
                                  }
                                });
                                if (cartId != null) {
                                  updateCart(cartId!);
                                }
                              },
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              displayedProducts.removeAt(index);
                              // Aquí tu lógica para actualizar el carrito
                            });
                            if (cartId != null) {
                              updateCart(cartId!);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              16.0, 8.0, 16.0, 12.0), // Aumenta el padding inferior aún más
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Total:",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text("Bs${calcularTotal()}",
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const MyApp()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlueAccent, // Azul Suave
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                        ),
                        child: const Text("Seguir comprando"),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Navegar a la pantalla PantallaPago
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const PantallaPago()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF1E272E), // Lila o Morado Claro
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                      ),
                      child: const Text(
                        "Tramitar Pedido",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
