import 'package:ekosatsss/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // FirebaseAuthException için eklendi
import 'package:provider/provider.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleRegistration() async {
    final authService = Provider.of<AuthService>(context, listen: false);

    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
        _showErrorSnackbar('Lütfen e-posta ve şifre alanlarını doldurun.');
        return;
    }

    setState(() {
      _isLoading = true;
    });

    String? errorMessage;
    try {
      final userCredential = await authService.signUp(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      
      if (userCredential == null) {
        // Eğer AuthService içinde özel bir hata yakalanıp null döndürüldüyse, 
        // burada genel bir hata mesajı gösterebiliriz (veya AuthService'i hata mesajını döndürecek şekilde güncelleyebiliriz).
        errorMessage = 'Kayıt başarısız. Lütfen bilgileri kontrol edin.';
      }
      // Başarılı kayıt sonrası yönlendirme AuthWrapper tarafından otomatik olarak yapılacak.

    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'Şifre çok zayıf. Lütfen daha güçlü bir şifre seçin.';
          break;
        case 'email-already-in-use':
          errorMessage = 'Bu e-posta adresi zaten kullanımda.';
          break;
        case 'invalid-email':
          errorMessage = 'Lütfen geçerli bir e-posta adresi girin.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'E-posta/Şifre ile girişe izin verilmiyor. Lütfen Firebase ayarlarınızı kontrol edin.';
          break;
        default:
          errorMessage = 'Hata oluştu: ${e.message}';
          break;
      }
    } catch (e) {
      errorMessage = 'Kayıt sırasında bilinmeyen bir sorun oluştu.';
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      if (errorMessage != null) {
        _showErrorSnackbar(errorMessage);
      } else {
        // Başarılı kayıt sonrası mesaj göster ve giriş ekranına dön
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Kayıt başarılı! Artık giriş yapabilirsiniz.')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kayıt Ol'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      extendBodyBehindAppBar: true, 
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
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white,
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(15),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 50),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28.0),
                    child: Column(
                      children: [
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email, color: Theme.of(context).colorScheme.primary),
                          ),
                        ),
                        const SizedBox(height: 20.0),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Şifre (en az 6 karakter)',
                            prefixIcon: Icon(Icons.lock, color: Theme.of(context).colorScheme.primary),
                          ),
                        ),
                        const SizedBox(height: 30.0),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : () => _handleRegistration(),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Kayıt Ol'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

