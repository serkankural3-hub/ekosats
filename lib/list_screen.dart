import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ekosatsss/auth_service.dart';
import 'package:ekosatsss/detail_screen.dart';
import 'package:ekosatsss/services/connectivity_service.dart';
import 'package:ekosatsss/services/offline_cache_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ekosatsss/empty_cart_list_screen.dart';
import 'package:ekosatsss/services/auto_exit_service.dart';
import 'package:ekosatsss/models/cart_model.dart';

class ListScreen extends StatefulWidget {
	const ListScreen({super.key});

	@override
	State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
	final AuthService _authService = AuthService();
	String? _userRole;
	String _searchQuery = '';
	String _selectedStatus = 'Tümü';
	DateTime? _selectedDate;

	final List<String> _statusOptions = [
		'Tümü',
		'Yaş İmalat',
		'Kurutmada',
		'Kurutmadan Çıkış',
		'Fırından Çıkış',
		'Fırında',
	];

	@override
	void initState() {
		super.initState();
		_fetchUserRole();
		// Liste ekranına girildiğinde bir kez kontrol et
		AutoExitService.runOnce();
	}

	Future<void> _fetchUserRole() async {
		final user = FirebaseAuth.instance.currentUser;
		if (user != null) {
			final email = user.email?.toLowerCase();
			String? role;
			if (email == 'pres@ekos.com') {
				role = 'Pres sorumlusu';
			} else if (email == 'firin@ekos.com') {
				role = 'Fırın Sorumlusu';
			} else if (email == 'laborant@ekos.com') {
				role = 'Laborant';
			} else if (email == 'admin@ekos.com') {
				role = 'admin';
			} else {
				role = await _authService.getUserRole(user.uid);
			}
			if (mounted) {
				setState(() => _userRole = role);
			}
		}
	}

	void _selectDate() async {
		final picked = await showDatePicker(
			context: context,
			initialDate: _selectedDate ?? DateTime.now(),
			firstDate: DateTime(2020),
			lastDate: DateTime.now(),
		);
		if (picked != null) {
			setState(() => _selectedDate = picked);
		}
	}

	bool _matchesFilters(Map<String, dynamic> data) {
		// Pres sorumlusu sadece "Yaş İmalat" ve "Boş Araba" görebilir
		if (_userRole == 'Pres sorumlusu') {
			final status = (data['status'] ?? '').toString().toLowerCase();
			if (!status.contains('yaş') && !status.contains('boş')) {
				return false;
			}
		}

		if (_searchQuery.isNotEmpty) {
			final barcode = (data['barcode'] ?? data['cartNumber'] ?? '').toString().toLowerCase();
			if (!barcode.contains(_searchQuery.toLowerCase())) return false;
		}
		if (_selectedStatus != 'Tümü') {
			final status = (data['status'] ?? 'Yaş İmalat').toString().toLowerCase();
			if (_selectedStatus == 'Kurutmada') {
				if (!status.contains('kurut') || status.contains('çık')) return false;
			} else if (_selectedStatus == 'Kurutmadan Çıkış') {
				if (!(status.contains('kurut') && status.contains('çık'))) return false;
			} else if (_selectedStatus == 'Fırından Çıkış') {
				if (!(status.contains('fır') && status.contains('çık'))) return false;
			} else if (_selectedStatus == 'Fırında') {
				if (!status.contains('fır') || status.contains('çık')) return false;
			} else if (_selectedStatus == 'Yaş İmalat') {
				if (!status.contains('yaş')) return false;
			}
		}
		if (_selectedDate != null) {
			final createdAtRaw = data['createdAt'];
			DateTime? createdAt;
			if (createdAtRaw is Timestamp) {
				createdAt = createdAtRaw.toDate();
			} else if (createdAtRaw is int) {
				createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtRaw);
			}
			
			if (createdAt != null) {
				final recordDate = DateTime(createdAt.year, createdAt.month, createdAt.day);
				final filterDate = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
				if (recordDate != filterDate) return false;
			}
		}
		return true;
	}

	Widget _buildListViewFromDocs(List<QueryDocumentSnapshot> docs) {
		return ListView.builder(
			itemCount: docs.length,
			padding: const EdgeInsets.all(12),
			itemBuilder: (context, index) {
				final doc = docs[index];
				final data = doc.data() as Map<String, dynamic>;
				final cartNumber = (data['cartNumber'] ?? doc.id).toString();
				return _buildCard(cartNumber, data);
			},
		);
	}

	Widget _buildListViewFromData(List<Map<String, dynamic>> items) {
		return ListView.builder(
			itemCount: items.length,
			padding: const EdgeInsets.all(12),
			itemBuilder: (context, index) {
				final data = items[index];
				final id = (data['cartNumber'] ?? data['id'] ?? '').toString();
				return _buildCard(id, data);
			},
		);
	}

	Widget _buildCard(String docId, Map<String, dynamic> data) {
		final createdAtRaw = data['createdAt'];
		final createdAt = createdAtRaw is Timestamp 
			? createdAtRaw.toDate() 
			: (createdAtRaw is int 
				? DateTime.fromMillisecondsSinceEpoch(createdAtRaw) 
				: null);
		final status = data['status'] ?? 'Yaş İmalat';

		Color borderColor;
		Color statusBgColor;
		Color statusTextColor;
		IconData iconData;

			switch (status) {
			case 'Kurutmada':
				borderColor = Colors.orange[400]!;
				statusBgColor = Colors.orange[50]!;
				statusTextColor = Colors.orange[800]!;
				iconData = Icons.water_drop;
				break;
			case 'Kurutmadan Çıkış':
				borderColor = Colors.deepOrange[400]!;
				statusBgColor = Colors.deepOrange[50]!;
				statusTextColor = Colors.deepOrange[800]!;
				iconData = Icons.exit_to_app;
				break;
			case 'Fırında':
				borderColor = Colors.red[400]!;
				statusBgColor = Colors.red[50]!;
				statusTextColor = Colors.red[800]!;
				iconData = Icons.local_fire_department;
				break;
			case 'Fırından Çıkış':
				borderColor = Colors.deepOrange[400]!;
				statusBgColor = Colors.deepOrange[50]!;
				statusTextColor = Colors.deepOrange[800]!;
				iconData = Icons.exit_to_app;
				break;
			default:
				borderColor = Colors.grey[400]!;
				statusBgColor = Colors.grey[100]!;
				statusTextColor = Colors.grey[800]!;
				iconData = Icons.inventory_2;
		}

		return GestureDetector(
			onTap: () {
				// Data'dan Item objesi oluştur
				final dateTimeRaw = data['dateTime'];
				final dateTime = dateTimeRaw is Timestamp 
					? dateTimeRaw.toDate() 
					: (dateTimeRaw is int 
						? DateTime.fromMillisecondsSinceEpoch(dateTimeRaw) 
						: DateTime.now());
				
								final record = CartRecord(
									id: docId,
									cartNumber: docId,
									cartType: data['cartType'] as String? ?? '',
									productType: data['productType'] as String? ?? '',
									product: data['product'] as String? ?? '',
									color: data['color'] as String? ?? '',
									dateTime: dateTime,
									status: data['status'] as String? ?? '',
									productQuantity: data['productQuantity'] as int? ?? 0,
									workOrder: data['workOrder'] as String? ?? '',
									description: data['description'] as String? ?? '',
									createdBy: data['createdBy'] as String? ?? '',
									createdAt: (data['createdAt'] is Timestamp) ? (data['createdAt'] as Timestamp).toDate() : dateTime,
								);

								Navigator.push(
									context,
									MaterialPageRoute(builder: (context) => DetailScreen(record: record)),
								);
			},
			child: Container(
				margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
				decoration: BoxDecoration(
					color: Colors.white,
					borderRadius: BorderRadius.circular(16),
					border: Border.all(color: borderColor, width: 1),
					boxShadow: [
						BoxShadow(
							color: Colors.black.withOpacity(0.03),
							blurRadius: 6,
							offset: const Offset(0, 2),
						),
					],
				),
				child: Padding(
					padding: const EdgeInsets.all(16),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							Row(
							mainAxisAlignment: MainAxisAlignment.spaceBetween,
							children: [
								Flexible(
									child: Text(
										'Barkod: ${data['cartNumber'] ?? data['barcode'] ?? docId}',
										style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
										overflow: TextOverflow.ellipsis,
									),
								),
								const SizedBox(width: 8),
								Container(
									padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
									decoration: BoxDecoration(
										color: statusBgColor,
										borderRadius: BorderRadius.circular(20),
									),
									child: Row(
										mainAxisSize: MainAxisSize.min,
										children: [
											Icon(iconData, color: borderColor, size: 18),
											const SizedBox(width: 6),
											Text(
												status,
												style: TextStyle(color: statusTextColor, fontWeight: FontWeight.bold),
											),
										],
									),
								),
							],
						),
						const SizedBox(height: 12),
						Row(
							mainAxisAlignment: MainAxisAlignment.spaceBetween,
							children: [
								Expanded(
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											Text(
												// For Pres sorumlusu show product name and color instead of productType
												_userRole == 'Pres sorumlusu'
													? 'Ürün: ${data['product'] ?? ''}${(data['color'] ?? '').toString().isNotEmpty ? ' - ${data['color']}' : ''}'
													: 'Ürün Çeşidi: ${data['productType'] ?? ''}',
												style: TextStyle(color: Colors.grey[700], fontSize: 13),
												maxLines: 2,
												overflow: TextOverflow.ellipsis,
											),
											const SizedBox(height: 4),
											Text(
												'Adet: ${data['productQuantity'] ?? 0}',
												style: TextStyle(color: Colors.grey[700], fontSize: 13),
											),
										],
									),
								),
								const SizedBox(width: 8),
								Column(
									crossAxisAlignment: CrossAxisAlignment.end,
									children: [
										Text(
											createdAt != null ? DateFormat('dd/MM/yyyy HH:mm').format(createdAt) : 'Tarih yok',
											style: TextStyle(color: Colors.grey[600], fontSize: 13),
										),
										const SizedBox(height: 4),
										Text(
											'Sorumlu: ${data['createdBy'] ?? ''}',
											style: TextStyle(color: Colors.grey[600], fontSize: 13),
										),
									],
								),
							],
						),
					],
				),
			),
		),
	);
}	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('Pres Kayıt Listesi'),
				backgroundColor: Theme.of(context).primaryColor,
				foregroundColor: Colors.white,
				actions: [
					if (_userRole == 'admin')
						IconButton(
							icon: const Icon(Icons.shopping_cart),
							tooltip: 'Boş Araba Listesi',
							onPressed: () {
								Navigator.push(
									context,
									MaterialPageRoute(builder: (context) => const EmptyCartListScreen()),
								);
							},
						),
				],
			),
			body: _userRole == null
					? const Center(child: CircularProgressIndicator())
					: Column(
							children: [
								Container(
									padding: const EdgeInsets.all(12),
									color: Colors.grey[100],
									child: Column(
										children: [
											TextField(
												onChanged: (value) => setState(() => _searchQuery = value),
												decoration: InputDecoration(
													hintText: 'Barkod ara...',
													prefixIcon: const Icon(Icons.search),
													suffixIcon: _searchQuery.isNotEmpty
															? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _searchQuery = ''))
															: null,
													border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
													contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
												),
											),
											const SizedBox(height: 12),
											Row(
												children: [
													Expanded(
														child: DropdownButton<String>(
															isExpanded: true,
															value: _selectedStatus,
															items: _statusOptions.map((status) => DropdownMenuItem(value: status, child: Text(status))).toList(),
															onChanged: (value) => value != null ? setState(() => _selectedStatus = value) : null,
														),
													),
													const SizedBox(width: 12),
													Expanded(
														child: OutlinedButton.icon(
															onPressed: _selectDate,
															icon: const Icon(Icons.calendar_today),
															label: Text(_selectedDate == null ? 'Tarih' : DateFormat('dd/MM/yyyy').format(_selectedDate!)),
														),
													),
													if (_selectedDate != null)
														IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _selectedDate = null)),
												],
											),
										],
									),
								),
								Expanded(
									child: StreamBuilder<QuerySnapshot>(
										stream: () {
											final currentEmail = FirebaseAuth.instance.currentUser?.email;
											if (_userRole == 'admin' || _userRole == 'Laborant') {
												return FirebaseFirestore.instance.collection('cart_records').orderBy('createdAt', descending: true).snapshots();
											} else if (_userRole == 'Pres sorumlusu' && currentEmail != null) {
												return FirebaseFirestore.instance.collection('cart_records').where('createdBy', isEqualTo: currentEmail).snapshots();
											}
											return const Stream<QuerySnapshot>.empty();
										}(),
										builder: (context, snapshot) {
											final connectivity = Provider.of<ConnectivityService>(context, listen: false);
											final cache = Provider.of<OfflineCacheService>(context, listen: false);
											final isOnline = connectivity.isOnline;

											if (!isOnline) {
												return FutureBuilder<List<Map<String, dynamic>>>(
													future: cache.getCachedRecords(),
													builder: (context, cacheSnap) {
														if (cacheSnap.connectionState == ConnectionState.waiting) {
															return const Center(child: CircularProgressIndicator());
														}
														if (cacheSnap.hasError || !cacheSnap.hasData) {
															return const Center(child: Text('Çevrimdışı veri bulunamadı.'));
														}

											final currentEmail = FirebaseAuth.instance.currentUser?.email;
											final cached = cacheSnap.data!..sort((a, b) {
												final aCreatedAt = a['createdAt'];
												final bCreatedAt = b['createdAt'];
												
												final aDate = aCreatedAt is Timestamp 
													? aCreatedAt.toDate() 
													: (aCreatedAt is int 
														? DateTime.fromMillisecondsSinceEpoch(aCreatedAt) 
														: DateTime.fromMillisecondsSinceEpoch(0));
												
												final bDate = bCreatedAt is Timestamp 
													? bCreatedAt.toDate() 
													: (bCreatedAt is int 
														? DateTime.fromMillisecondsSinceEpoch(bCreatedAt) 
														: DateTime.fromMillisecondsSinceEpoch(0));
												
												return bDate.compareTo(aDate);
											});														final filteredCached = cached.where((data) {
															if (!(_userRole == 'admin' || _userRole == 'Laborant')) {
																if (_userRole == 'Pres sorumlusu' && currentEmail != null) {
																	if (data['createdBy'] != currentEmail) return false;
																}
															}
															return _matchesFilters(data);
														}).toList();

														if (filteredCached.isEmpty) {
															return const Center(child: Text('Çevrimdışı kayıt bulunamadı.'));
														}

														return _buildListViewFromData(filteredCached);
													},
												);
											}

											if (snapshot.hasError) return Center(child: Text('Hata: ${snapshot.error}'));
											if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
											if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
												return const Center(child: Text('Henüz Pres kaydı bulunmamaktadır.'));
											}

											final docs = snapshot.data!.docs;
											for (final doc in docs) {
												cache.cacheRecord(doc.id, doc.data() as Map<String, dynamic>);
											}

											final filteredDocs = docs.where((doc) => _matchesFilters(doc.data() as Map<String, dynamic>)).toList();
											
											// Pres kullanıcısı için sort et (orderBy olmadığı için)
											if (_userRole == 'Pres sorumlusu') {
												filteredDocs.sort((a, b) {
													final aCreatedAt = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
													final bCreatedAt = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
													if (aCreatedAt == null || bCreatedAt == null) return 0;
													return bCreatedAt.compareTo(aCreatedAt);
												});
											}

											if (filteredDocs.isEmpty) {
												return Center(
													child: Column(
														mainAxisAlignment: MainAxisAlignment.center,
														children: [
															Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
															const SizedBox(height: 16),
															Text('Filtre kriterleriyle eşleşen kayıt yok', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
														],
													),
												);
											}

											return _buildListViewFromDocs(filteredDocs);
										},
									),
								),
							],
						),
		);
	}
}
