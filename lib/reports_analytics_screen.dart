import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ReportsAnalyticsScreen extends StatefulWidget {
	const ReportsAnalyticsScreen({super.key});

	@override
	State<ReportsAnalyticsScreen> createState() => _ReportsAnalyticsScreenState();
}

class _ReportsAnalyticsScreenState extends State<ReportsAnalyticsScreen>
		with SingleTickerProviderStateMixin {
	late TabController _tabController;
	DateTime? _startDate;
	DateTime? _endDate;
	bool _loading = false;

	// Product data maps (normalized key -> value)
	final Map<String, int> _produced = {};
	final Map<String, int> _processFire = {};
	final Map<String, int> _finalFire = {};
	final Map<String, int> _depotFire = {};
	final Map<String, String> _displayName = {};

	// Normalize product name for matching
	String _norm(String s) => s.trim().toLowerCase();

	// Safely parse integer from dynamic value
	int _intFrom(dynamic v) {
		if (v == null) return 0;
		if (v is int) return v;
		if (v is double) return v.toInt();
		return int.tryParse(v.toString()) ?? 0;
	}

	// Add product data with normalized key
	void _addProduct(String rawName, int quantity, Map<String, int> targetMap) {
		final normalized = _norm(rawName);
		if (normalized.isEmpty) return;
		
		_displayName.putIfAbsent(normalized, () => rawName.trim());
		targetMap[normalized] = (targetMap[normalized] ?? 0) + quantity;
	}

	@override
	void initState() {
		super.initState();
		_tabController = TabController(length: 2, vsync: this);
	}

	@override
	void dispose() {
		_tabController.dispose();
		super.dispose();
	}

	Future<void> _pickStartDate() async {
		final now = DateTime.now();
		final picked = await showDatePicker(
			context: context,
			initialDate: _startDate ?? now,
			firstDate: DateTime(2000),
			lastDate: DateTime(2100),
		);
		if (picked != null) setState(() => _startDate = picked);
	}

	Future<void> _pickEndDate() async {
		final now = DateTime.now();
		final picked = await showDatePicker(
			context: context,
			initialDate: _endDate ?? now,
			firstDate: DateTime(2000),
			lastDate: DateTime(2100),
		);
		if (picked != null) setState(() => _endDate = picked);
	}

	Future<void> _runQuery() async {
		if (_startDate == null || _endDate == null) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Lütfen başlangıç ve bitiş tarihlerini seçin')),
			);
			return;
		}

		if (_startDate!.isAfter(_endDate!)) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Başlangıç tarihi bitiş tarihinden önce olmalı')),
			);
			return;
		}

		setState(() {
			_loading = true;
			_produced.clear();
			_processFire.clear();
			_finalFire.clear();
			_depotFire.clear();
			_displayName.clear();
		});

		final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
		final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);

		final startTs = Timestamp.fromDate(start);
		final endTs = Timestamp.fromDate(end);

		final firestore = FirebaseFirestore.instance;

		// 1) Produced: cart_records - SADECE "Fırından Çıkış" durumundaki kayıtlar
		final cartSnap = await firestore
				.collection('cart_records')
				.get(); // Tüm kayıtları çek, hafızada filtrele

		for (var doc in cartSnap.docs) {
			final data = doc.data();
			
			// Tarih kontrolü
			final docDate = data['dateTime'] as Timestamp?;
			if (docDate == null) continue;
			final docDateTime = docDate.toDate();
			if (docDateTime.isBefore(start) || docDateTime.isAfter(end)) continue;
			
			// Status kontrolü - SADECE "Fırından Çıkış" olanları say
			final status = (data['status'] ?? '').toString().toLowerCase();
			if (!status.contains('fırından çıkış')) continue;
			
			final rawProduct = (data['productType'] ?? data['product'] ?? '').toString();
			final rawColor = (data['color'] ?? data['renk'] ?? '').toString();
			if (rawProduct.isEmpty) continue;
			
			// Ürün adı + Renk formatında kaydet
			final productWithColor = rawColor.isNotEmpty ? '$rawProduct - $rawColor' : rawProduct;
			
			final qty = _intFrom(data['productQuantity'] ?? data['quantity'] ?? data['toplamAdet']);
			_addProduct(productWithColor, qty, _produced);
		}

		// 2) Process fire: 'fire_records' collection
		final procSnap = await firestore
				.collection('fire_records')
				.where('created_at', isGreaterThanOrEqualTo: startTs)
				.where('created_at', isLessThanOrEqualTo: endTs)
				.get();

		for (var doc in procSnap.docs) {
			final data = doc.data();
			final rawName = (data['product_name'] ?? data['product'] ?? data['urunAdi'] ?? '').toString();
			if (rawName.isEmpty) continue;
			
			final fireCount = _intFrom(data['fire_count'] ?? data['fireCount'] ?? data['quantity']);
			_addProduct(rawName, fireCount, _processFire);
		}

		// 3) Final control: 'final_control_records'
		final finalSnap = await firestore
				.collection('final_control_records')
				.where('createdAt', isGreaterThanOrEqualTo: startTs)
				.where('createdAt', isLessThanOrEqualTo: endTs)
				.get();

		for (var doc in finalSnap.docs) {
			final data = doc.data();
			final rawName = (data['urunAdi'] ?? data['productName'] ?? data['product'] ?? '').toString();
			if (rawName.isEmpty) continue;
			
			final fireCount = _intFrom(data['fireAdedi'] ?? data['fireCount'] ?? data['fire']);
			_addProduct(rawName, fireCount, _finalFire);
		}

		// 4) Depot control: 'depot_control_records'
		final depotSnap = await firestore
				.collection('depot_control_records')
				.where('createdAt', isGreaterThanOrEqualTo: startTs)
				.where('createdAt', isLessThanOrEqualTo: endTs)
				.get();

		for (var doc in depotSnap.docs) {
			final data = doc.data();
			final palets = (data['palets'] as List<dynamic>?) ?? [];
			for (var palet in palets) {
				final rawName = (palet['productName'] ?? palet['product'] ?? '').toString();
				if (rawName.isEmpty) continue;
				
				final fireCount = _intFrom(palet['fireCount'] ?? palet['fire_count'] ?? palet['fire']);
				_addProduct(rawName, fireCount, _depotFire);
			}
		}

		// Merge fire records with production records
		_mergeSimilarProducts();

		setState(() => _loading = false);
	}

	// Find matching product key using fuzzy matching
	String? _findMatch(String key, Set<String> targetKeys) {
		// Exact match
		if (targetKeys.contains(key)) return key;

		// Substring match
		for (final targetKey in targetKeys) {
			if (targetKey.contains(key) || key.contains(targetKey)) {
				return targetKey;
			}
		}

		// Word-based matching
		final keyWords = key.split(RegExp(r'[^a-z0-9]+'))
			..removeWhere((s) => s.length < 2);
		
		if (keyWords.length < 2) return null;

		for (final targetKey in targetKeys) {
			final targetWords = targetKey.split(RegExp(r'[^a-z0-9]+'))
				..removeWhere((s) => s.length < 2);
			
			if (targetWords.length < 2) continue;

			final commonWords = keyWords.toSet().intersection(targetWords.toSet());
			if (commonWords.length >= 2 && commonWords.length >= keyWords.length * 0.5) {
				return targetKey;
			}
		}

		return null;
	}

	// Merge fire data into production keys
	void _mergeSimilarProducts() {
		final producedKeys = _produced.keys.toSet();

		void mergeMap(Map<String, int> fireMap) {
			final keysToMerge = fireMap.keys.where((k) => !producedKeys.contains(k)).toList();
			
			for (final key in keysToMerge) {
				final match = _findMatch(key, producedKeys);
				if (match != null) {
					fireMap[match] = (fireMap[match] ?? 0) + fireMap[key]!;
					fireMap.remove(key);
				}
			}
		}

		mergeMap(_processFire);
		mergeMap(_finalFire);
		mergeMap(_depotFire);
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			backgroundColor: Colors.grey[50],
			appBar: AppBar(
				title: const Text('Raporlar & Analiz'),
				elevation: 0,
				bottom: TabBar(
					controller: _tabController,
					indicatorWeight: 3,
					tabs: const [
						Tab(icon: Icon(Icons.bar_chart), text: 'Üretim Raporu'),
						Tab(icon: Icon(Icons.pending_actions), text: 'Canlı Durum'),
					],
				),
			),
			body: TabBarView(
				controller: _tabController,
				children: [
					_buildProductionTab(),
					_buildLiveStatusTab(),
				],
			),
		);
	}

	Widget _buildProductionTab() {
		return Padding(
			padding: const EdgeInsets.all(16.0),
			child: Column(
				children: [
					Card(
						elevation: 2,
						shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
						child: Padding(
							padding: const EdgeInsets.all(16.0),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Row(
										children: [
											Icon(Icons.date_range, color: Colors.blue[700]),
											const SizedBox(width: 8),
											const Text(
												'Tarih Aralığı Seçin',
												style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
											),
										],
									),
									const SizedBox(height: 16),
									Row(
										children: [
											Expanded(
												child: OutlinedButton.icon(
													icon: const Icon(Icons.calendar_today),
													label: Text(
														_startDate == null 
															? 'Başlangıç Tarihi' 
															: DateFormat('dd/MM/yyyy').format(_startDate!),
													),
													style: OutlinedButton.styleFrom(
														padding: const EdgeInsets.symmetric(vertical: 16),
														side: BorderSide(color: Colors.blue[300]!),
														shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
													),
													onPressed: _pickStartDate,
												),
											),
											const SizedBox(width: 12),
											Expanded(
												child: OutlinedButton.icon(
													icon: const Icon(Icons.event),
													label: Text(
														_endDate == null 
															? 'Bitiş Tarihi' 
															: DateFormat('dd/MM/yyyy').format(_endDate!),
													),
													style: OutlinedButton.styleFrom(
														padding: const EdgeInsets.symmetric(vertical: 16),
														side: BorderSide(color: Colors.blue[300]!),
														shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
													),
													onPressed: _pickEndDate,
												),
											),
										],
									),
									const SizedBox(height: 12),
									SizedBox(
										width: double.infinity,
										child: ElevatedButton.icon(
											icon: _loading 
												? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
												: const Icon(Icons.search),
											label: const Text('Raporu Oluştur', style: TextStyle(fontSize: 16)),
											style: ElevatedButton.styleFrom(
												padding: const EdgeInsets.symmetric(vertical: 16),
												shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
												backgroundColor: Colors.blue[700],
											),
											onPressed: (_startDate != null && _endDate != null && !_loading) ? _runQuery : null,
										),
									),
								],
							),
						),
					),
					const SizedBox(height: 16),
					Expanded(child: _buildResultsList()),
				],
			),
		);
	}

	Widget _buildResultsList() {
		if (_loading) {
			return const Center(
				child: Column(
					mainAxisAlignment: MainAxisAlignment.center,
					children: [
						CircularProgressIndicator(),
						SizedBox(height: 16),
						Text('Veriler yükleniyor...', style: TextStyle(fontSize: 16)),
					],
				),
			);
		}
		if (_produced.isEmpty) {
			return Center(
				child: Column(
					mainAxisAlignment: MainAxisAlignment.center,
					children: [
						Icon(Icons.analytics_outlined, size: 80, color: Colors.grey[400]),
						const SizedBox(height: 16),
						Text(
							'Henüz veri yok',
							style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[700]),
						),
						const SizedBox(height: 8),
						Text(
							'Tarih aralığını seçip raporu oluşturun',
							style: TextStyle(fontSize: 14, color: Colors.grey[600]),
						),
					],
				),
			);
		}

		final products = _produced.keys.toList()
			..sort((a, b) => _produced[b]!.compareTo(_produced[a]!));

		return ListView.builder(
			itemCount: products.length,
			itemBuilder: (context, index) {
				final normalizedKey = products[index];
				final displayName = _displayName[normalizedKey] ?? normalizedKey;
				final produced = _produced[normalizedKey]!;
				final processFire = _processFire[normalizedKey] ?? 0;
				final finalFire = _finalFire[normalizedKey] ?? 0;
				final depotFire = _depotFire[normalizedKey] ?? 0;
				final totalFire = processFire + finalFire + depotFire;
				final firePercent = produced > 0 ? (totalFire / produced) * 100 : 0.0;
				final fireColor = firePercent > 5 ? Colors.red : (firePercent > 3 ? Colors.orange : Colors.green);

				return Card(
					margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
					elevation: 1,
					shape: RoundedRectangleBorder(
						borderRadius: BorderRadius.circular(12),
						side: BorderSide(color: Colors.grey[200]!, width: 1),
					),
					child: InkWell(
						borderRadius: BorderRadius.circular(12),
						onTap: () => _showProductDetails(
							context,
							displayName,
							produced,
							processFire,
							finalFire,
							depotFire,
							firePercent,
						),
						child: Padding(
							padding: const EdgeInsets.all(16.0),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Row(
										children: [
										  Expanded(
												child: Text(
													displayName,
													style: const TextStyle(
														fontSize: 16,
														fontWeight: FontWeight.bold,
													),
												),
											),
											Container(
												padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
												decoration: BoxDecoration(
													color: fireColor.withOpacity(0.1),
													borderRadius: BorderRadius.circular(20),
													border: Border.all(color: fireColor, width: 1.5),
												),
												child: Text(
													'%${firePercent.toStringAsFixed(1)}',
													style: TextStyle(
														color: fireColor,
														fontWeight: FontWeight.bold,
														fontSize: 14,
													),
												),
											),
										],
									),
									const SizedBox(height: 12),
									Row(
										mainAxisAlignment: MainAxisAlignment.spaceBetween,
										children: [
											_buildStatChip(Icons.inventory_2, 'Üretim', '$produced', Colors.blue),
											_buildStatChip(Icons.warning_amber, 'Fire', '$totalFire', fireColor),
										],
									),
								],
							),
						),
					),
				);
			},
		);
	}

	Widget _buildStatChip(IconData icon, String label, String value, Color color) {
		return Row(
			children: [
				Icon(icon, size: 18, color: color),
				const SizedBox(width: 4),
				Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						Text(
							label,
							style: TextStyle(fontSize: 11, color: Colors.grey[600]),
						),
						Text(
							value,
							style: TextStyle(
								fontSize: 15,
								fontWeight: FontWeight.bold,
								color: color,
							),
						),
					],
				),
			],
		);
	}

	void _showProductDetails(
		BuildContext context,
		String productName,
		int produced,
		int processFire,
		int finalFire,
		int depotFire,
		double firePercent,
	) {
		final totalFire = processFire + finalFire + depotFire;
		final fireColor = firePercent > 5 ? Colors.red : (firePercent > 3 ? Colors.orange : Colors.green);
		
		showModalBottomSheet(
			context: context,
			isScrollControlled: true,
			backgroundColor: Colors.transparent,
			builder: (context) => Container(
				decoration: const BoxDecoration(
					color: Colors.white,
					borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
				),
				padding: const EdgeInsets.all(24.0),
				child: Column(
					mainAxisSize: MainAxisSize.min,
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						Row(
							children: [
								Container(
									padding: const EdgeInsets.all(12),
									decoration: BoxDecoration(
										color: Colors.blue[50],
										borderRadius: BorderRadius.circular(12),
									),
									child: Icon(Icons.inventory_2, color: Colors.blue[700], size: 28),
								),
								const SizedBox(width: 12),
								Expanded(
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											const Text(
												'Ürün Detayı',
												style: TextStyle(fontSize: 14, color: Colors.grey),
											),
											Text(
												productName,
												style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
											),
										],
									),
								),
							],
						),
						const SizedBox(height: 24),
						Container(
							padding: const EdgeInsets.all(16),
							decoration: BoxDecoration(
								gradient: LinearGradient(
									colors: [Colors.blue[50]!, Colors.blue[100]!],
								),
								borderRadius: BorderRadius.circular(12),
							),
							child: Row(
								mainAxisAlignment: MainAxisAlignment.spaceAround,
								children: [
									_buildDetailMetric('Üretim', '$produced', Icons.factory, Colors.blue[700]!),
									Container(width: 1, height: 40, color: Colors.blue[200]),
									_buildDetailMetric('Fire', '$totalFire', Icons.warning_amber, fireColor),
								],
							),
						),
						const SizedBox(height: 20),
						_buildDetailRow('Proses Fire', '$processFire adet', Colors.orange[700]!),
						const SizedBox(height: 8),
						_buildDetailRow('Final Kontrol Fire', '$finalFire adet', Colors.orange[700]!),
						const SizedBox(height: 8),
						_buildDetailRow('Depo Fire', '$depotFire adet', Colors.orange[700]!),
						const Divider(height: 32),
						Container(
							padding: const EdgeInsets.all(16),
							decoration: BoxDecoration(
								color: fireColor.withOpacity(0.1),
								borderRadius: BorderRadius.circular(12),
								border: Border.all(color: fireColor, width: 2),
							),
							child: Row(
								mainAxisAlignment: MainAxisAlignment.spaceBetween,
								children: [
									Row(
										children: [
											Icon(Icons.trending_up, color: fireColor),
											const SizedBox(width: 8),
											const Text(
												'Fire Oranı',
												style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
											),
										],
									),
									Text(
										'%${firePercent.toStringAsFixed(2)}',
										style: TextStyle(
											fontSize: 24,
											fontWeight: FontWeight.bold,
											color: fireColor,
										),
									),
								],
							),
						),
						const SizedBox(height: 16),
					],
				),
			),
		);
	}

	Widget _buildDetailMetric(String label, String value, IconData icon, Color color) {
		return Column(
			children: [
				Icon(icon, color: color, size: 32),
				const SizedBox(height: 8),
				Text(
					value,
					style: TextStyle(
						fontSize: 24,
						fontWeight: FontWeight.bold,
						color: color,
					),
				),
				Text(
					label,
					style: const TextStyle(fontSize: 14, color: Colors.grey),
				),
			],
		);
	}

	Widget _buildDetailRow(String label, String value, Color color) {
		return Padding(
			padding: const EdgeInsets.symmetric(vertical: 4),
			child: Row(
				mainAxisAlignment: MainAxisAlignment.spaceBetween,
				children: [
					Text(label, style: const TextStyle(fontSize: 15)),
					Text(
						value,
						style: TextStyle(
							fontSize: 15,
							color: color,
							fontWeight: FontWeight.w600,
						),
					),
				],
			),
		);
	}

	Widget _buildLiveStatusTab() {
		return DefaultTabController(
			length: 3,
			child: Column(
				children: [
					Material(
						color: Colors.white,
						elevation: 1,
						child: const TabBar(
							labelColor: Colors.blue,
							unselectedLabelColor: Colors.grey,
							indicatorWeight: 3,
							tabs: [
								Tab(icon: Icon(Icons.local_fire_department), text: 'Fırında'),
								Tab(icon: Icon(Icons.ac_unit), text: 'Kurutmada'),
								Tab(icon: Icon(Icons.timer), text: 'Kurutma Süreleri'),
							],
						),
					),
					Expanded(
						child: TabBarView(
							children: [
								_buildStatusStream('Fırında', 'Fırından Çıkış'),
								_buildStatusStream('Kurutmada', 'Kurutmadan Çıkış'),
								_buildDryingDurationAnalysis(),
							],
						),
					),
				],
			),
		);
	}

	Widget _buildStatusStream(String targetStatus, String excludeStatus) {
		return StreamBuilder<QuerySnapshot>(
			stream: FirebaseFirestore.instance
				.collection('cart_records')
				.where('status', isEqualTo: targetStatus)
				.snapshots(),
			builder: (context, snapshot) {
				if (snapshot.connectionState == ConnectionState.waiting) {
					return const Center(child: CircularProgressIndicator());
				}

				if (snapshot.hasError) {
					return Center(child: Text('Hata: ${snapshot.error}'));
				}

				if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
					return Center(
						child: Column(
							mainAxisAlignment: MainAxisAlignment.center,
							children: [
								Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
								const SizedBox(height: 16),
								Text(
									'$targetStatus durumunda araba yok',
									style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
								),
							],
						),
					);
				}

				final carts = snapshot.data!.docs;
				final totalCarts = carts.length;

				int totalQuantity = 0;
				for (var doc in carts) {
					final data = doc.data() as Map<String, dynamic>;
					totalQuantity += _intFrom(data['productQuantity'] ?? data['quantity'] ?? data['toplamAdet']);
				}

				return Column(
					children: [
						Container(
							padding: const EdgeInsets.all(20),
							decoration: BoxDecoration(
								gradient: LinearGradient(
									colors: [Colors.blue[50]!, Colors.blue[100]!],
								),
							),
							child: Row(
								mainAxisAlignment: MainAxisAlignment.spaceAround,
								children: [
									_buildSummaryCard('Toplam Araba', '$totalCarts', Icons.local_shipping),
									Container(width: 2, height: 60, color: Colors.blue[200]),
									_buildSummaryCard('Toplam Adet', '$totalQuantity', Icons.inventory_2),
								],
							),
						),
						Expanded(
							child: ListView.builder(
								padding: const EdgeInsets.all(12),
								itemCount: carts.length,
								itemBuilder: (context, index) {
									final doc = carts[index];
									final data = doc.data() as Map<String, dynamic>;
									
									final cartNumber = data['cartNumber'] ?? data['cartId'] ?? doc.id;
									final productName = (data['product'] ?? data['productType'] ?? 'Belirtilmemiş').toString();
									final color = (data['color'] ?? data['renk'] ?? '-').toString();
									final quantity = _intFrom(data['productQuantity'] ?? data['quantity'] ?? data['toplamAdet']);
									final timestamp = data['createdAt'] as Timestamp?;
									final dateStr = timestamp != null 
										? DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate())
										: '-';

									return Card(
										margin: const EdgeInsets.symmetric(vertical: 6),
										elevation: 1,
										shape: RoundedRectangleBorder(
											borderRadius: BorderRadius.circular(12),
											side: BorderSide(color: Colors.grey[200]!, width: 1),
										),
										child: Padding(
											padding: const EdgeInsets.all(16.0),
											child: Row(
												children: [
													Container(
														width: 50,
														height: 50,
														decoration: BoxDecoration(
															color: Colors.blue[50],
															borderRadius: BorderRadius.circular(10),
														),
														child: Icon(Icons.qr_code_2, color: Colors.blue[700], size: 28),
													),
													const SizedBox(width: 16),
													Expanded(
														child: Column(
															crossAxisAlignment: CrossAxisAlignment.start,
															children: [
																Text(
																	'Barkod: $cartNumber',
																	style: const TextStyle(
																		fontWeight: FontWeight.bold,
																		fontSize: 15,
																	),
																),
																const SizedBox(height: 6),
																Text(
																	'$productName${color != '-' ? ' - $color' : ''}',
																	style: TextStyle(color: Colors.grey[700], fontSize: 14),
																),
																const SizedBox(height: 4),
																Row(
																	children: [
																		Icon(Icons.inventory_2, size: 14, color: Colors.grey[600]),
																		const SizedBox(width: 4),
																		Text('$quantity adet', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
																		const SizedBox(width: 12),
																		Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
																		const SizedBox(width: 4),
																		Text(dateStr, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
																	],
																),
															],
														),
													),
												],
											),
										),
									);
								},
							),
						),
					],
				);
			},
		);
	}

	Widget _buildSummaryCard(String label, String value, IconData icon) {
		return Column(
			children: [
				Icon(icon, size: 36, color: Colors.blue[700]),
				const SizedBox(height: 8),
				Text(
					value,
					style: TextStyle(
						fontSize: 28,
						fontWeight: FontWeight.bold,
						color: Colors.blue[800],
					),
				),
				Text(
					label,
					style: TextStyle(fontSize: 14, color: Colors.grey[700]),
				),
			],
		);
	}

	Widget _buildDryingDurationAnalysis() {
		return StreamBuilder<QuerySnapshot>(
			stream: FirebaseFirestore.instance
				.collection('cart_records')
				.where('status', isEqualTo: 'Kurutmadan Çıkış')
				.snapshots(),
			builder: (context, snapshot) {
				if (snapshot.connectionState == ConnectionState.waiting) {
					return const Center(child: CircularProgressIndicator());
				}

				if (snapshot.hasError) {
					return Center(child: Text('Hata: ${snapshot.error}'));
				}

				if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
					return Center(
						child: Column(
							mainAxisAlignment: MainAxisAlignment.center,
							children: [
								Icon(Icons.timer_off, size: 80, color: Colors.grey[400]),
								const SizedBox(height: 16),
								Text(
									'Henüz kurutma verisi yok',
									style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700]),
								),
								const SizedBox(height: 8),
								Text(
									'Kurutmadan çıkış yapılan arabalar burada görünecek',
									style: TextStyle(fontSize: 14, color: Colors.grey[600]),
									textAlign: TextAlign.center,
								),
							],
						),
					);
				}

				final carts = snapshot.data!.docs;
				final List<Map<String, dynamic>> dryingData = [];
				int totalMinutes = 0;
				int validCount = 0;

				for (var doc in carts) {
					final data = doc.data() as Map<String, dynamic>;
					final dryingIn = data['dryingIn'] as Timestamp?;
					final dryingOut = data['dryingOut'] as Timestamp?;

					if (dryingIn != null && dryingOut != null) {
						final duration = dryingOut.toDate().difference(dryingIn.toDate());
						final hours = duration.inHours;
						final minutes = duration.inMinutes % 60;

						if (duration.inMinutes > 0) {
							dryingData.add({
								'cartNumber': data['cartNumber'] ?? doc.id,
								'product': (data['product'] ?? 'Belirtilmemiş').toString(),
								'color': (data['color'] ?? '-').toString(),
								'durationMinutes': duration.inMinutes,
								'hours': hours,
								'minutes': minutes,
								'dryingIn': dryingIn.toDate(),
								'dryingOut': dryingOut.toDate(),
							});
							totalMinutes += duration.inMinutes;
							validCount++;
						}
					}
				}

				// Süreye göre sırala (en uzun süre üstte)
				dryingData.sort((a, b) => b['durationMinutes'].compareTo(a['durationMinutes']));

				final avgMinutes = validCount > 0 ? totalMinutes / validCount : 0;
				final avgHours = (avgMinutes / 60).floor();
				final avgMins = (avgMinutes % 60).floor();

				return Column(
					children: [
						Container(
							padding: const EdgeInsets.all(20),
							decoration: BoxDecoration(
								gradient: LinearGradient(
									colors: [Colors.purple[50]!, Colors.purple[100]!],
								),
							),
							child: Row(
								mainAxisAlignment: MainAxisAlignment.spaceAround,
								children: [
									Column(
										children: [
											Icon(Icons.timer, size: 36, color: Colors.purple[700]),
											const SizedBox(height: 8),
											Text(
												'${avgHours}s ${avgMins}dk',
												style: TextStyle(
													fontSize: 28,
													fontWeight: FontWeight.bold,
													color: Colors.purple[800],
												),
											),
											Text(
												'Ortalama Kurutma',
												style: TextStyle(fontSize: 14, color: Colors.grey[700]),
											),
										],
									),
									Container(width: 2, height: 60, color: Colors.purple[200]),
									Column(
										children: [
											Icon(Icons.inventory_2, size: 36, color: Colors.purple[700]),
											const SizedBox(height: 8),
											Text(
												'$validCount',
												style: TextStyle(
													fontSize: 28,
													fontWeight: FontWeight.bold,
													color: Colors.purple[800],
												),
											),
											Text(
												'Toplam Kayıt',
												style: TextStyle(fontSize: 14, color: Colors.grey[700]),
											),
										],
									),
								],
							),
						),
						Expanded(
							child: dryingData.isEmpty
								? Center(
										child: Text(
											'Kurutma süresi hesaplanabilir veri yok',
											style: TextStyle(color: Colors.grey[600]),
										),
									)
								: ListView.builder(
										padding: const EdgeInsets.all(12),
										itemCount: dryingData.length,
										itemBuilder: (context, index) {
											final item = dryingData[index];
											final hours = item['hours'] as int;
											final minutes = item['minutes'] as int;
											final durationColor = hours < 24 
												? Colors.green 
												: (hours < 48 ? Colors.orange : Colors.red);

											return Card(
												margin: const EdgeInsets.symmetric(vertical: 6),
												elevation: 1,
												shape: RoundedRectangleBorder(
													borderRadius: BorderRadius.circular(12),
													side: BorderSide(color: Colors.grey[200]!, width: 1),
												),
												child: Padding(
													padding: const EdgeInsets.all(16.0),
													child: Column(
														crossAxisAlignment: CrossAxisAlignment.start,
														children: [
															Row(
																mainAxisAlignment: MainAxisAlignment.spaceBetween,
																children: [
																	Expanded(
																		child: Column(
																			crossAxisAlignment: CrossAxisAlignment.start,
																			children: [
																				Text(
																					'Barkod: ${item['cartNumber']}',
																					style: const TextStyle(
																						fontWeight: FontWeight.bold,
																						fontSize: 15,
																					),
																				),
																				const SizedBox(height: 4),
																				Text(
																					'${item['product']}${item['color'] != '-' ? ' - ${item['color']}' : ''}',
																					style: TextStyle(color: Colors.grey[700], fontSize: 13),
																				),
																			],
																		),
																	),
																	Container(
																		padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
																		decoration: BoxDecoration(
																			color: durationColor.withOpacity(0.1),
																			borderRadius: BorderRadius.circular(20),
																			border: Border.all(color: durationColor, width: 2),
																		),
																		child: Text(
																			'${hours}s ${minutes}dk',
																			style: TextStyle(
																				color: durationColor,
																				fontWeight: FontWeight.bold,
																				fontSize: 16,
																			),
																		),
																	),
																],
															),
															const SizedBox(height: 12),
															Row(
																children: [
																	Icon(Icons.login, size: 14, color: Colors.grey[600]),
																	const SizedBox(width: 4),
																	Text(
																		'Giriş: ${DateFormat('dd/MM/yyyy HH:mm').format(item['dryingIn'])}',
																		style: TextStyle(color: Colors.grey[600], fontSize: 12),
																	),
																	const SizedBox(width: 16),
																	Icon(Icons.logout, size: 14, color: Colors.grey[600]),
																	const SizedBox(width: 4),
																	Text(
																		'Çıkış: ${DateFormat('dd/MM/yyyy HH:mm').format(item['dryingOut'])}',
																		style: TextStyle(color: Colors.grey[600], fontSize: 12),
																	),
																],
															),
														],
													),
												),
											);
										},
									),
						),
					],
				);
			},
		);
	}
}

