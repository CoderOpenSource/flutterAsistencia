import 'package:mapas_api/screens/cart_screen.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'dart:convert'; // Para decodificar el JSON
import 'package:http/http.dart' as http;
import 'package:mapas_api/widgets/favoritos_page.dart';
import 'package:mapas_api/widgets/reserva_screen.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Para hacer peticiones HTTP

class ProductDetailScreen extends StatefulWidget {
  final int productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  _ProductDetailScreenState createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Map? product;
  List? imageUrls;
  bool isLoading = true; // Añade esta variable para rastrear el estado de carga
  List? productDetails;
  Color? selectedColor;
  int cantidad = 1;
  bool isFavorited = false;
  TextStyle headerStyle = const TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  );

  TextStyle regularStyle = const TextStyle(
    fontSize: 18,
    color: Colors.black87,
  );

  TextStyle descriptionStyle = const TextStyle(
    fontSize: 16,
    color: Colors.black54,
  );

  TextStyle discountStyle = const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: Colors.red,
  );
  int? selectedVariantId;
  double getDiscountedPrice(dynamic originalPrice, dynamic discount) {
    double price =
        (originalPrice is String) ? double.parse(originalPrice) : originalPrice;
    double discountPercentage =
        (discount is String) ? double.parse(discount) : discount;
    return price * (1 - discountPercentage / 100);
  }

  // Mapa de colores
  Map<String, String> colorMap = {
    "Rojo": "#FF0000",
    "Verde": "#00FF00",
    "Celeste": "#0000FF",
    "Amarillo": "#FFFF00",
    "Naranja": "#FFA500",
    "Púrpura": "#800080",
    "Multicolor": "#00FFFF",
    "Magenta": "#FF00FF",
    "Lima": "#00FF7F",
    "Rosado": "#FFC0CB",
    "Beige": "#F5F5DC",
    "Marrón": "#8B4513",
    "Violeta": "#9400D3",
    "Turquesa": "#40E0D0",
    "Salmon": "#FA8072",
    "Oro": "#FFD700",
    "Azul": "#C0C0C0",
    "Gris": "#808080",
    "Negro": "#000000",
    "Blanco": "#FFFFFF",
    // ... Puedes agregar más colores si lo deseas
  };

  Color getColorFromName(String name) {
    // Utiliza el nombre del color para buscar en el mapa. Si no se encuentra, devuelve blanco por defecto.
    String hex = colorMap[name] ?? colorMap['Blanco']!;
    return Color(int.parse(hex.substring(1, 7), radix: 16) + 0xFF000000);
  }

  @override
  void initState() {
    super.initState();
    fetchProduct();
    fetchProductDetails();
    checkIfFavorited();
  }

  fetchProduct() async {
    final response = await http.get(Uri.parse(
        'http://137.184.190.92/productos/productos/${widget.productId}'));
    if (response.statusCode == 200) {
      var decodedData = json.decode(response.body);
      setState(() {
        product = decodedData;
        imageUrls = product!['imagenes']
            .map((imagen) => imagen['ruta_imagen'])
            .toList();
        isLoading = false; // Desactiva el estado de carga
      });
    } else {
      // Puedes manejar errores aquí si la petición no fue exitosa.
      print('Error al obtener datos: ${response.statusCode}');
    }
  }

  fetchProductDetails() async {
    final response = await http
        .get(Uri.parse('http://137.184.190.92/productos/productosdetalle/'));
    if (response.statusCode == 200) {
      var decodedData = json.decode(response.body);
      setState(() {
        productDetails = decodedData;
        print(decodedData);
      });
    } else {
      print('Error al obtener detalles: ${response.statusCode}');
    }
  }

  checkIfFavorited() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = int.parse(prefs.getString('userId') ?? '0');
    final response = await http.get(Uri.parse(
        'http://137.184.190.92/productos_favoritos/productos_favoritos/'));
    if (response.statusCode == 200) {
      var decodedData = json.decode(response.body);
      // Puedes adaptar esta línea si la estructura de tu respuesta es diferente
      var found = decodedData
          .where((item) =>
              item['usuario'] == userId && item['producto'] == widget.productId)
          .toList();
      if (found.length > 0) {
        setState(() {
          isFavorited = true;
        });
      }
    }
  }

  Future<void> gestionarProductoFavorito(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final int usuarioLogueado = int.parse(prefs.getString('userId') ?? '0');
    const url =
        'http://137.184.190.92/productos_favoritos/productos_favoritos/';

    if (isFavorited) {
      // Eliminar producto de favoritos

      // Paso 1: Obtener el ID del producto favorito
      final responseGet = await http.get(Uri.parse(url));
      if (responseGet.statusCode != 200) {
        throw Exception('Error al obtener la lista de productos favoritos');
      }

      List<dynamic> productosFavoritos = json.decode(responseGet.body);
      int? idProductoFavorito;
      for (var producto in productosFavoritos) {
        if (producto['usuario'] == usuarioLogueado &&
            producto['producto'] == widget.productId) {
          idProductoFavorito = producto['id'];
          break; // Salimos del bucle una vez que encontramos el producto
        }
      }

      if (idProductoFavorito == null) {
        throw Exception('Producto favorito no encontrado');
      }

      // Paso 2: Eliminar el producto favorito
      final responseDelete =
          await http.delete(Uri.parse('$url$idProductoFavorito/'));
      if (responseDelete.statusCode == 200 ||
          responseDelete.statusCode == 204) {
        const snackBar = SnackBar(
          content: Text('Producto eliminado de favoritos'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        );
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
        setState(() {
          isFavorited = false;
        });
      } else {
        const snackBar = SnackBar(
          content: Text('Error al eliminar el producto de favoritos'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        );
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }
    } else {
      // Agregar producto a favoritos
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'usuario': usuarioLogueado,
          'producto': widget.productId,
        }),
      );
      if (response.statusCode == 201) {
        const snackBar = SnackBar(
          content: Text('Producto agregado a favoritos'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        );
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
        setState(() {
          isFavorited = true;
        });
      } else {
        const snackBar = SnackBar(
          content: Text('Error al agregar el producto a favoritos'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        );
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }
    }
  }

  Future<bool> yaReservoProducto(int usuarioId, int productoDetalleId) async {
    final url = Uri.parse('http://137.184.190.92/reservas/reservas/');

    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json; charset=UTF-8',
      });

      if (response.statusCode == 200) {
        final List<dynamic> reservas =
            json.decode(response.body) as List<dynamic>;

        // Busca entre todas las reservas para ver si alguna coincide con usuarioId y productoDetalleId
        for (var reserva in reservas) {
          if (reserva['usuario'] == usuarioId &&
              reserva['producto_detalle'] == productoDetalleId) {
            return true; // Encuentra una reserva que coincide
          }
        }
        return false; // No se encontró ninguna reserva que coincida
      }
    } catch (e) {
      print('Error al conectar con el API: $e');
    }
    return false; // Si hay un error en la solicitud o el estado no es 200
  }

  Future<void> reservarProducto(
      int productoDetalleId, int cantidad, BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final int usuarioLogueado = int.parse(prefs.getString('userId') ?? '0');

    // Verificar si el usuario ya ha reservado este producto
    final bool yaReservo =
        await yaReservoProducto(usuarioLogueado, productoDetalleId);
    if (yaReservo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ya has reservado este producto.'),
          backgroundColor: Colors.amber,
          duration: Duration(seconds: 3),
        ),
      );
      return; // No continuar con la reserva si ya existe una.
    }

    // Proceder con la reserva si no existe una previa
    final Uri url = Uri.parse('http://137.184.190.92/reservas/reservas/');
    try {
      final response = await http.post(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, dynamic>{
          'usuario': usuarioLogueado,
          'producto_detalle': productoDetalleId,
          'cantidad': cantidad,
        }),
      );

      if (response.statusCode == 201) {
        print('Reserva realizada con éxito.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Producto reservado exitosamente!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        print(
            'Error al realizar la reserva: ${response.statusCode} - ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al realizar la reserva: ${response.body}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error al conectar con el API: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al conectar con el API: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> handleAddToCart(
      int variantId, int cantidad, BuildContext context) async {
    const String baseUrl = "http://137.184.190.92/transacciones";

    final prefs = await SharedPreferences.getInstance();
    final int userId = int.parse(prefs.getString('userId') ?? '0');

    try {
      int? carritoId;

      // Obtener todos los carritos
      final response = await http.get(
        Uri.parse('$baseUrl/carritos/'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      final List<dynamic> carritosData = json.decode(response.body);

      // Buscar un carrito que pertenezca al usuario
      final carritoUsuario = carritosData.firstWhere(
        (carrito) =>
            carrito['usuario'] == userId && carrito['disponible'] == true,
        orElse: () => null,
      );

      // Si se encuentra un carrito del usuario, usar ese carrito
      if (carritoUsuario != null) {
        print('estoy aqui');
        carritoId = carritoUsuario['id'] as int;
      } else {
        print('hola');
        // Si no, crear un nuevo carrito
        final newCarritoResponse = await http.post(
          Uri.parse('$baseUrl/carritos/'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'usuario': userId,
          }),
        );

        final Map<String, dynamic> newCarritoData =
            json.decode(newCarritoResponse.body);
        carritoId = newCarritoData['id'] as int;
      }

      // Comprobar si el variantId ya está en el carrito
      print('Este es el carritoId : $carritoId');
      final detallesResponse = await http.get(
        Uri.parse('$baseUrl/carrito_detalle/'),
        headers: {
          'Content-Type': 'application/json',
        },
      );
      final List<dynamic> todosLosDetalles = json.decode(detallesResponse.body);

      // Filtrar para obtener solo los detalles que corresponden al carritoId
      final detallesData = todosLosDetalles.where((detalle) {
        return detalle['carrito'] ==
            carritoId; // Asegúrate de que esto coincida con la estructura de tus datos
      }).toList();
      for (var detalle in detallesData) {
        if (detalle['productodetalle'] == variantId) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('El producto ya se encuentra en el carrito.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
          return; // Termina la ejecución de la función
        }
      }
      final responseDetalle = await http.post(
        Uri.parse('$baseUrl/carrito_detalle/'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'carrito': carritoId,
          'productodetalle': variantId,
          'productodetalle_id': variantId,
          'cantidad': cantidad,
        }),
      );
      print('Cuerpo de la solicitud enviada:');
      print(json.encode({
        'carrito': carritoId,
        'productodetalle': variantId,
        'productodetalle_id': variantId,
        'cantidad': cantidad,
      }));

      print(
          'Respuesta de añadir producto detalle: ${responseDetalle.statusCode}');
      print('Cuerpo de respuesta: ${responseDetalle.body}');

      print('Producto añadido al carrito exitosamente!');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Producto añadido al carrito exitosamente!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (error) {
      print('Hubo un error al añadir el producto al carrito: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hubo un error al añadir el producto al carrito.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      // Si está cargando, muestra un indicador de carga
      return const Scaffold(
        backgroundColor: Color(0xFF1E272E),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    // De lo contrario, muestra el contenido
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      appBar: AppBar(
        leading: const BackButton(color: Colors.white),
        title: const Text(
          "Detalles del Producto",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors
                .white, // Establecer el color del texto a negro (o el color que desees)
            fontSize: 20, // Tamaño del texto, ajusta según tu necesidad
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FavoritosPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.calendar_month_outlined,
              color: Colors.white,
              size: 40,
            ), // Icono de carrito
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ReservaScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.shopping_cart,
              color: Colors.white,
              size: 40,
            ), // Icono de carrito
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      const CartScreen(), // Navega a CartScreen
                ),
              );
            },
          ),
        ],
        backgroundColor: const Color(0xFF1E272E),
        elevation: 0,
        centerTitle:
            true, // Esto asegura que el título esté centrado en el AppBar
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              children: <Widget>[
                // Aquí el Carousel
                CarouselSlider(
                  options: CarouselOptions(
                    height: MediaQuery.of(context).size.height *
                        0.6, // Cambia esto para modificar la altura
                    autoPlay: true, // Autoplay para el carrusel
                    viewportFraction:
                        1.0, // Esto hará que la imagen ocupe toda la pantalla en ancho
                    // Añadimos estas líneas para los indicadores:
                    enableInfiniteScroll: true,
                    pauseAutoPlayOnTouch: true,
                    enlargeCenterPage: true,
                    onPageChanged: (index, reason) {
                      setState(() {
                        // Aquí puedes actualizar algún estado relacionado con el índice de la imagen actual si es necesario
                      });
                    },
                  ),
                  items: imageUrls!.map((url) {
                    return Container(
                      margin: const EdgeInsets.all(5.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                            10.0), // Añadimos bordes redondeados
                        boxShadow: const [
                          BoxShadow(
                            color: Colors
                                .black26, // Cambia este color para la sombra
                            offset: Offset(0.0, 4.0),
                            blurRadius: 5.0,
                          )
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius:
                            const BorderRadius.all(Radius.circular(10.0)),
                        child: Image.network(
                          url,
                          width: MediaQuery.of(context).size.width,
                          fit: BoxFit.cover,
                          loadingBuilder: (BuildContext context, Widget child,
                              ImageChunkEvent? loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                                child: Text('Error al cargar la imagen.'));
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),
                // A continuación, otros detalles del producto como precio, nombre, etc.
                Text(product!['nombre'].replaceAll('Ã±', 'ñ'),
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold)),
                Column(
                  children: [
                    if (double.parse(product!['descuento_porcentaje']) > 0)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Precio original: ${product!['precio']}',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey),
                          ),
                          Text(
                            'Precio con descuento: ${getDiscountedPrice(product!['precio'], product!['descuento_porcentaje']).toStringAsFixed(2)}',
                            style: discountStyle,
                          ),
                        ],
                      )
                    else
                      Text(
                        'Precio: ${product!['precio']}',
                        style: regularStyle,
                      ),
                  ],
                ),

                // ... (otros detalles que desees agregar)
                Text(
                  'Descripción: ${product!['descripcion'].replaceAll('Ã±', 'ñ')}',
                  style: descriptionStyle,
                ),

                Text(
                  'Colores disponibles:',
                  style: descriptionStyle,
                ),
                if (productDetails != null)
                  Wrap(
                    spacing:
                        12.0, // Aumenta el espacio entre los íconos de colores
                    children: productDetails!
                        .where((detail) =>
                            detail['producto']['id'] == widget.productId)
                        .map((detail) {
                      print(detail);
                      Color currentColor =
                          getColorFromName(detail['color']['nombre']);
                      print('Colores disponibles');
                      print(getColorFromName(detail['color']['nombre']));
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedColor = currentColor;
                            selectedVariantId = detail['id']
                                as int; // Guardamos el variantId aquí
                          });
                        },
                        child: Material(
                          elevation: 2.0, // Añade elevación para dar sombra
                          shape: const CircleBorder(),
                          child: Container(
                            width:
                                38, // Aumenta el tamaño para que sean más fáciles de tocar
                            height: 38,
                            decoration: BoxDecoration(
                              color: currentColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selectedColor == currentColor
                                    ? Colors.black
                                    : Colors.transparent,
                                width:
                                    2.5, // Aumenta el grosor del borde seleccionado
                              ),
                              boxShadow: [
                                // Sombra suave
                                if (selectedColor == currentColor)
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    spreadRadius: 1,
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Text(
                      "Cantidad: ",
                      style: TextStyle(fontSize: 18.0),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: () {
                        setState(() {
                          if (cantidad > 1) {
                            cantidad--;
                          }
                        });
                      },
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Text(
                        cantidad.toString(),
                        style: const TextStyle(fontSize: 18.0),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        setState(() {
                          cantidad++;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Color(0xFF1E272E), // Elige el color que prefieras
                  width:
                      2.0, // Ajusta el grosor del borde según lo que necesites
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment
                    .spaceEvenly, // Cambiado a spaceEvenly para mejor distribución
                children: <Widget>[
                  IconButton(
                    icon: Icon(
                      isFavorited ? Icons.favorite : Icons.favorite_border,
                      color: isFavorited ? Colors.red : Colors.grey,
                    ),
                    onPressed: () => gestionarProductoFavorito(context),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E272E),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation:
                          5, // Agrega esta línea para dar sombra al botón
                    ),
                    onPressed: () async {
                      if (selectedVariantId != null) {
                        await reservarProducto(
                            selectedVariantId!, cantidad, context);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Por favor selecciona un color.'),
                            backgroundColor: Colors.orange,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'RESERVAR',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E272E),
                      padding: const EdgeInsets.all(20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation:
                          5, // Agrega esta línea para dar sombra al botón
                    ),
                    onPressed: () async {
                      if (selectedVariantId != null) {
                        await handleAddToCart(
                            selectedVariantId!, cantidad, context);
                      } else {
                        print(
                            'Por favor selecciona un color antes de añadir al carrito.');
                      }
                    },
                    child: const Text(
                      'AÑADIR AL CARRO',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
