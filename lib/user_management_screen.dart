import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ekosatsss/auth_service.dart';
import 'package:ekosatsss/models/user_model.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final AuthService _authService = AuthService();
  final List<String> _roles = [
    'admin',
    'user', // Varsayılan rol
    'Pres sorumlusu',
    'Fırın Sorumlusu',
    'Üretim mühendisi',
    'Kalite şefi',
    'Üretim şefi',
    'Laborant',
    'Genel Müdür'
  ];
  final List<String> _statuses = [
    'approved',
    'disabled',
  ];

  void _showDeleteConfirmationDialog(String uid, String email) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Kullanıcıyı Sil'),
          content: Text(
              '"$email" kullanıcısını pasifleştirmek istiyor musunuz? (Silme yerine kullanıcı devre dışı bırakılacaktır).'),
          actions: <Widget>[
            TextButton(
              child: const Text('İptal'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Devre Dışı Bırak', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                try {
                  await _authService.disableUser(uid);
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Kullanıcı devre dışı bırakıldı'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Devre dışı bırakma hatası: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showEditUserDialog(String uid, UserModel user) {
    final formKey = GlobalKey<FormState>();
    String selectedRole = _roles.contains(user.role) ? user.role : 'user';
    String selectedStatus =
        _statuses.contains(user.status) ? user.status : 'approved';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Kullanıcıyı Düzenle'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(labelText: 'Rol'),
                  items: _roles
                      .map((r) =>
                          DropdownMenuItem<String>(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => selectedRole = v ?? selectedRole,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(labelText: 'Durum'),
                  items: _statuses
                      .map((s) =>
                          DropdownMenuItem<String>(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => selectedStatus = v ?? selectedStatus,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .update({
                    'role': selectedRole,
                    'status': selectedStatus,
                  });
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Kullanıcı güncellendi'),
                          backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Hata: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
  }

  void _showAddUserDialog() {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String? selectedRole = _roles.first; // Varsayılan olarak ilk rolü seç

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Yeni Kullanıcı Ekle'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'E-posta'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null ||
                            value.isEmpty ||
                            !value.contains('@')) {
                          return 'Geçerli bir e-posta girin.';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: passwordController,
                      decoration: const InputDecoration(
                          labelText: 'Şifre (en az 6 karakter)'),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Şifre en az 6 karakter olmalıdır.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(labelText: 'Rol'),
                      items: _roles.map((String role) {
                        return DropdownMenuItem<String>(
                          value: role,
                          child: Text(role),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedRole = newValue;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Lütfen bir rol seçin' : null,
                    ),
                  ],
                ),
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('İptal'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Oluştur ve Yeni Ekle'),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  await _authService.signUp(
                    emailController.text.trim(),
                    passwordController.text.trim(),
                    role: selectedRole!,
                    signOut: false, // Admin eklediği için oturumu kapatma
                  );
                  // Formu temizle
                  emailController.clear();
                  passwordController.clear();
                  // Odak noktasını kaldırarak klavyeyi gizle
                  FocusScope.of(context).unfocus();
                }
              },
            ),
            ElevatedButton(
              child: const Text('Oluştur ve Kapat'),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  await _authService.signUp(
                    emailController.text.trim(),
                    passwordController.text.trim(),
                    role: selectedRole!,
                    signOut: false, // Admin eklediği için oturumu kapatma
                  );
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kullanıcı Yönetimi'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddUserDialog,
        icon: const Icon(Icons.add),
        label: const Text('Yeni Kullanıcı Ekle'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Sadece onaylı (approved) kullanıcıları göster: devre dışı bırakılmış kullanıcılar listede görünmez
        stream: FirebaseFirestore.instance.collection('users').where('status', isEqualTo: 'approved').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Kayıtlı kullanıcı bulunmuyor.'));
          }

          return ListView(
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              UserModel user = UserModel.fromMap(data, doc.id);
              String uid = doc.id;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.email,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Rol değiştirme menüsü
                          Expanded(
                            child: DropdownButton<String>(
                              value: _roles.contains(user.role)
                                  ? user.role
                                  : 'user',
                              onChanged: (String? newRole) {
                                if (newRole != null) {
                                  _authService.updateUserRole(uid, newRole);
                                }
                              },
                              items: _roles.map<DropdownMenuItem<String>>(
                                  (String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value,
                                      overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              isExpanded: true,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Düzenleme butonu
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            tooltip: 'Kullanıcıyı Düzenle',
                            onPressed: () => _showEditUserDialog(uid, user),
                          ),
                          const SizedBox(width: 8),
                          // Silme butonu
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Kullanıcıyı Sil',
                            onPressed: () =>
                                _showDeleteConfirmationDialog(uid, user.email),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

