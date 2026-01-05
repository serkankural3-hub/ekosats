import 'package:ekosatsss/auth_service.dart';
import 'package:ekosatsss/login_screen.dart';
import 'package:ekosatsss/scanner_screen.dart';
import 'package:ekosatsss/theme_provider.dart';
import 'package:ekosatsss/services/connectivity_service.dart';
import 'package:ekosatsss/services/offline_cache_service.dart';
import 'package:ekosatsss/splash_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ekosatsss/list_screen.dart';
import 'package:ekosatsss/oven_list_screen.dart';
import 'package:ekosatsss/cart_form_screen.dart';
import 'package:ekosatsss/cart_list_screen.dart';
import 'package:ekosatsss/lab_records_screen.dart';
import 'package:ekosatsss/final_control_form_screen.dart';
import 'package:ekosatsss/final_control_records_screen.dart';
import 'package:ekosatsss/empty_cart_list_screen.dart';
import 'package:ekosatsss/process_fire_records_screen.dart';
import 'package:ekosatsss/depot_control_form_screen.dart';
import 'package:ekosatsss/depot_control_records_screen.dart';
import 'package:ekosatsss/reports_analytics_screen.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<ConnectivityService>(create: (_) => ConnectivityService()),
        Provider<OfflineCacheService>(create: (_) => OfflineCacheService()),
      ],
      child: MaterialApp(
        title: 'Tuğla Fabrikası Takip',
        theme: ThemeProvider.lightTheme,
        debugShowCheckedModeBanner: false,
        home: AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final User? user = snapshot.data;
          if (user == null) {
            return const LoginScreen();
          }
          // Show HomeScreen; HomeScreen will render role-specific UI after resolving role.
          return const HomeScreen();
        }
        return const SplashScreen();
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late ConnectivityService _connectivityService;

  @override
  void initState() {
    super.initState();
    _connectivityService = ConnectivityService();
    
    // Connectivity değişikliklerini dinle ve senkronizasyonu trigger et
    _connectivityService.connectivityStream.listen((isOnline) {
      if (isOnline) {
        // Çevrimiçi olduktan sonra pending operasyonları senkronize et
        _connectivityService.syncPendingOperations().then((_) {
          // Senkronizasyon tamamlandıktan sonra listeleri güncelle
          _connectivityService.updateCache('cart_records');
          _connectivityService.updateCache('oven_records');
          _connectivityService.updateCache('press_records');
          
          // Kullanıcıya bildir
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Çevrimiçi olundu! Veriler senkronize ediliyor...'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        });
      }
    });
  }

  String? _getRoleFromEmail(String? email) {
    final lowerEmail = email?.toLowerCase();
    if (lowerEmail == 'pres@ekos.com') {
      return 'Pres sorumlusu';
    } else if (lowerEmail == 'firin@ekos.com') {
      return 'Fırın Sorumlusu';
    } else if (lowerEmail == 'laborant@ekos.com' || lowerEmail == 'lab@ekos.com') {
      return 'Laborant';
    } else if (lowerEmail == 'tugla@ekos.com') {
      return 'Tugla Sorumlusu';
    } else if (lowerEmail == 'depo@ekos.com') {
      return 'Depo Sorumlusu';
    } else if (lowerEmail == 'admin@ekos.com' || 
               lowerEmail == 'oytunsidal@ekos.com' ||
               lowerEmail == 'keremsidal@ekos.com' ||
               lowerEmail == 'sefaafyon@ekos.com' ||
               lowerEmail == 'ahmetkuscu@ekos.com' ||
               lowerEmail == 'mustafaakgul@ekos.com' ||
               lowerEmail == 'senaaydın@ekos.com') {
      return 'admin';
    }
    return 'user';
  }

  String _getUserDisplayName(String? email, String? role) {
    if (email == null) return role ?? 'Kullanıcı';
    
    final lowerEmail = email.toLowerCase();
    // Özel admin kullanıcıları için isim-soyisim mapping
    final Map<String, String> nameMapping = {
      'oytunsidal@ekos.com': 'Oytun Sidal',
      'keremsidal@ekos.com': 'Kerem Sidal',
      'sefaafyon@ekos.com': 'Sefa Afyon',
      'ahmetkuscu@ekos.com': 'Ahmet Kuşçu',
      'mustafaakgul@ekos.com': 'Mustafa Akgül',
      'senaaydın@ekos.com': 'Sena Aydın',
    };
    
    if (nameMapping.containsKey(lowerEmail)) {
      return nameMapping[lowerEmail]!;
    }
    
    // Diğer kullanıcılar için role göster
    return role ?? 'Kullanıcı';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userRole = _getRoleFromEmail(user?.email);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Ana Sayfa', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await Provider.of<AuthService>(context, listen: false).signOut();
            },
          )
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFD32F2F),
              const Color(0xFF9E9E9E),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 160,
                    height: 160,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(Radius.circular(20)),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 15,
                          spreadRadius: 2,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Text(
                      'Hoş Geldiniz, ${_getUserDisplayName(user?.email, userRole)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black45,
                            offset: Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Connectivity Indicator with Pending Operations Counter
                  StreamBuilder<bool>(
                    stream: ConnectivityService().connectivityStream,
                    initialData: true,
                    builder: (context, snapshot) {
                      final isOnline = snapshot.data ?? true;
                      return FutureBuilder<int>(
                        future: OfflineCacheService().getPendingOperationsCount(),
                        builder: (context, pendingSnapshot) {
                          final pendingCount = pendingSnapshot.data ?? 0;
                          
                          if (!isOnline) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF757575),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange, width: 2),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.cloud_off, color: Colors.white, size: 18),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Çevrimdışı Mod',
                                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  if (pendingCount > 0) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.hourglass_bottom, color: Colors.amber, size: 14),
                                        const SizedBox(width: 6),
                                        Text(
                                          '$pendingCount işlem bekleniyor',
                                          style: TextStyle(color: Colors.amber[200], fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Çevrimiçi olunca otomatik senkronize edilecek',
                                    style: TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
                                ],
                              ),
                            );
                          } else if (pendingCount > 0) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.blue[600],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.lightBlue, width: 2),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.sync, color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Senkronize ediliyor...',
                                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          '$pendingCount işlem senkronize edilecek',
                                          style: TextStyle(color: Colors.blue[100], fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                      // Eğer özel admin UID ile giriş yapılmışsa yalnızca kayıt düzenleme ve kullanıcı yönetimi göster
                  Builder(builder: (context) {
                      final currentUser = FirebaseAuth.instance.currentUser;
                      const specialAdminUid = '9Ekre1iG0raMeeAiPXXoaORSR2y2';
                      final isSpecialAdmin = currentUser != null && currentUser.uid == specialAdminUid;
                      if (isSpecialAdmin) {
                        final currentUserEmail = currentUser.email ?? '';
                        
                        return Column(
                          children: [
                            _buildModuleCard(
                              context,
                              title: 'Araba Kayıtlarını Düzenle',
                              icon: Icons.edit_document,
                              color: Colors.orange[400]!,
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const CartListScreen()));
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildModuleCard(
                              context,
                              title: 'Final Kontrol Kayıtları',
                              icon: Icons.assignment_turned_in,
                              color: Colors.deepOrange[600]!,
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => FinalControlRecordsScreen(userEmail: currentUserEmail)));
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildModuleCard(
                              context,
                              title: 'Raporlar',
                              icon: Icons.bar_chart,
                              color: Colors.teal[400]!,
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportsAnalyticsScreen()));
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildModuleCard(
                              context,
                              title: 'Boş Araba Listesi',
                              icon: Icons.shopping_cart,
                              color: Colors.purple[400]!,
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const EmptyCartListScreen()));
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildModuleCard(
                              context,
                              title: 'Proses Fire Kayıtları',
                              icon: Icons.fire_truck,
                              color: Colors.red[600]!,
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const ProcessFireRecordsScreen()));
                              },
                            ),
                                const SizedBox(height: 20),
                                _buildModuleCard(
                                  context,
                                  title: 'Depo Kontrol Kayıtları',
                                  icon: Icons.inventory_2,
                                  color: Colors.indigo[500]!,
                                  onTap: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => const DepotControlRecordsScreen()));
                                  },
                                ),
                            const SizedBox(height: 20),
                          ],
                        );
                      }
                          // Normal admin (admin@ekos.com) için de aynı modülleri göster
                          if (userRole == 'admin') {
                            final currentUserEmail = currentUser?.email ?? '';
                            return Column(
                              children: [
                                _buildModuleCard(
                                  context,
                                  title: 'Araba Kayıtlarını Düzenle',
                                  icon: Icons.edit_document,
                                  color: Colors.orange[400]!,
                                  onTap: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => const CartListScreen()));
                                  },
                                ),
                                const SizedBox(height: 20),
                                _buildModuleCard(
                                  context,
                                  title: 'Final Kontrol Kayıtları',
                                  icon: Icons.assignment_turned_in,
                                  color: Colors.deepOrange[600]!,
                                  onTap: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => FinalControlRecordsScreen(userEmail: currentUserEmail)));
                                  },
                                ),
                                const SizedBox(height: 20),
                                _buildModuleCard(
                                  context,
                                  title: 'Raporlar',
                                  icon: Icons.bar_chart,
                                  color: Colors.teal[400]!,
                                  onTap: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportsAnalyticsScreen()));
                                  },
                                ),
                                const SizedBox(height: 20),
                                _buildModuleCard(
                                  context,
                                  title: 'Boş Araba Listesi',
                                  icon: Icons.shopping_cart,
                                  color: Colors.purple[400]!,
                                  onTap: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => const EmptyCartListScreen()));
                                  },
                                ),
                                const SizedBox(height: 20),
                                _buildModuleCard(
                                  context,
                                  title: 'Proses Fire Kayıtları',
                                  icon: Icons.fire_truck,
                                  color: Colors.red[600]!,
                                  onTap: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => const ProcessFireRecordsScreen()));
                                  },
                                ),
                                const SizedBox(height: 20),
                                _buildModuleCard(
                                  context,
                                  title: 'Depo Kontrol Kayıtları',
                                  icon: Icons.inventory_2,
                                  color: Colors.indigo[500]!,
                                  onTap: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => const DepotControlRecordsScreen()));
                                  },
                                ),
                              ],
                            );
                          }
                      // Eğer Laborant ise barkod okut ve kayıtlarını göster
                      if (userRole == 'Laborant') {
                        return Column(
                          children: [
                            _buildModuleCard(
                              context,
                              title: 'Barkod Okut',
                              icon: Icons.qr_code_scanner,
                              color: Colors.purple[400]!,
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerScreen()));
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildModuleCard(
                              context,
                              title: 'Kayıtlarım',
                              icon: Icons.assignment,
                              color: Colors.purple[700]!,
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const LabRecordsScreen()));
                              },
                            ),
                          ],
                        );
                      }
                      // Eğer Pres sorumlusu ise sadece barkod okut ve pres kayıtlarını göster
                      if (userRole == 'Pres sorumlusu') {
                        return Column(
                          children: [
                            _buildModuleCard(
                              context,
                              title: 'Barkod Okut',
                              icon: Icons.qr_code_scanner,
                              color: Colors.blue[400]!,
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerScreen()));
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildModuleCard(
                              context,
                              title: 'Pres Kayıtlarını Görüntüle',
                              icon: Icons.list_alt,
                              color: Colors.green[400]!,
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const ListScreen()));
                              },
                            ),
                          ],
                        );
                      }
                      // Eğer Fırın sorumlusu ise sadece barkod okut ve fırın kayıtlarını göster
                      if (userRole == 'Fırın Sorumlusu') {
                        final user = FirebaseAuth.instance.currentUser;
                        final currentUserEmail = user?.email ?? '';
                        
                        return Column(
                          children: [
                            _buildModuleCard(
                              context,
                              title: 'Barkod Okut',
                              icon: Icons.qr_code_scanner,
                              color: Colors.orange[400]!,
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerScreen()));
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildModuleCard(
                              context,
                              title: 'Kurutma Kayıtlarını Görüntüle',
                              icon: Icons.local_fire_department,
                              color: Colors.red[400]!,
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const OvenListScreen()));
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildModuleCard(
                              context,
                              title: 'Final Kontrol Formu',
                              icon: Icons.assignment,
                              color: Colors.orange[600]!,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FinalControlFormScreen(userEmail: currentUserEmail),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildModuleCard(
                              context,
                              title: 'Final Kontrol Kayıtları',
                              icon: Icons.list_alt,
                              color: Colors.orange[800]!,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FinalControlRecordsScreen(userEmail: currentUserEmail),
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      }
                      // Eğer Tugla sorumlusu ise sadece barkod okut
                      if (userRole == 'Tugla Sorumlusu') {
                        return Column(
                          children: [
                            _buildModuleCard(
                              context,
                              title: 'Barkod Okut',
                              icon: Icons.qr_code_scanner,
                              color: Colors.orange[700]!,
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerScreen()));
                              },
                            ),
                          ],
                        );
                      }                      // Eğer Depo sorumlusu ise sadece depo kontrol formunu göster
                      if (userRole == 'Depo Sorumlusu') {
                        return Column(
                          children: [
                            _buildModuleCard(
                              context,
                              title: 'Boylandırma Kalite Kontrol',
                              icon: Icons.inventory_2,
                              color: Colors.indigo[400]!,
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const DepotControlFormScreen()));
                              },
                            ),
                          ],
                        );
                      }                      // Normal kullanıcı/ara yüz gösterimi (önceki butonlar)
                      return Column(
                        children: [
                          _buildModuleCard(
                            context,
                            title: 'Barkod Okut',
                            icon: Icons.qr_code_scanner,
                            color: Colors.indigo[400]!,
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerScreen()));
                            },
                          ),
                          const SizedBox(height: 20),
                          _buildModuleCard(
                            context,
                            title: 'Pres Kayıtlarını Görüntüle',
                            icon: Icons.list_alt,
                            color: Colors.green[400]!,
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const ListScreen()));
                            },
                          ),
                          const SizedBox(height: 20),
                          _buildModuleCard(
                            context,
                            title: 'Fırın Kayıtlarını Görüntüle',
                            icon: Icons.local_fire_department,
                            color: Colors.cyan[400]!,
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const OvenListScreen()));
                            },
                          ),
                          const SizedBox(height: 20),
                          _buildModuleCard(
                            context,
                            title: 'Araba Takip Formu',
                            icon: Icons.assignment,
                            color: Colors.orange[400]!,
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const CartFormScreen()));
                            },
                          ),
                          const SizedBox(height: 20),
                          _buildModuleCard(
                            context,
                            title: 'Araba Kayıtlarını Görüntüle',
                            icon: Icons.assignment_turned_in,
                            color: Colors.deepPurple[400]!,
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const CartListScreen()));
                            },
                          ),
                        ],
                      );
                    }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModuleCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 32, color: color),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tıklayarak başlayın',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: color, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
