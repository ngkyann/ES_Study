import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:esstudy/constants/var.dart';

class ShopPage extends StatefulWidget {
  final String userId;

  const ShopPage({super.key, required this.userId});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  @override
  Widget build(BuildContext context) {
    bool isVN = languageNotifier.value == "Tiếng Việt";

    return DefaultTabController(
      length: 3, // 3 Danh mục: Khung, Avatar, Hiệu ứng
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          title: Text(
            isVN ? "Cửa hàng vật phẩm" : "Item Shop",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          actions: [
            // Hiển thị số Xu hiện tại của User ngay trên thanh Shop
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.userId)
                  .snapshots(),
              builder: (context, snapshot) {
                int coins = 0;
                if (snapshot.hasData && snapshot.data!.exists) {
                  coins = (snapshot.data!.data()
                          as Map<String, dynamic>)['coins'] ??
                      0;
                }
                return Container(
                  margin:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.monetization_on,
                          color: Colors.amber, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        "$coins",
                        style: TextStyle(
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
          // THANH ĐIỀU HƯỚNG DANH MỤC SHOP
          bottom: TabBar(
            labelColor: primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: primaryColor,
            indicatorWeight: 3,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: [
              Tab(text: isVN ? "Khung" : "Frames"),
              Tab(text: isVN ? "Avatar" : "Avatars"),
              Tab(text: isVN ? "Hiệu ứng" : "Effects"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // 1. Danh mục Khung
            _buildShopGrid([
              ShopItemData(
                  id: "k1",
                  name: "Khung Lửa Học Thuật",
                  price: 150,
                  icon: Icons.local_fire_department,
                  color: Colors.orange),
              ShopItemData(
                  id: "k2",
                  name: "Khung Sao Lấp Lánh",
                  price: 300,
                  icon: Icons.star,
                  color: Colors.purple),
            ], isVN),

            // 2. Danh mục Avatar
            _buildShopGrid([
              ShopItemData(
                  id: "a1",
                  name: "Avatar Sói Chăm Chỉ",
                  price: 200,
                  icon: Icons.pets,
                  color: Colors.blueGrey),
              ShopItemData(
                  id: "a2",
                  name: "Avatar Phi Hành Gia",
                  price: 500,
                  icon: Icons.rocket_launch,
                  color: Colors.indigo),
            ], isVN),

            // 3. Danh mục Hiệu ứng
            _buildShopGrid([
              ShopItemData(
                  id: "h1",
                  name: "Hiệu ứng Pháo Hoa",
                  price: 100,
                  icon: Icons.celebration,
                  color: Colors.redAccent),
              ShopItemData(
                  id: "h2",
                  name: "Hiệu ứng Tuyết Rơi",
                  price: 250,
                  icon: Icons.ac_unit,
                  color: Colors.lightBlue),
            ], isVN),
          ],
        ),
      ),
    );
  }

  // Hàm xây dựng lưới Grid chứa vật phẩm
  Widget _buildShopGrid(List<ShopItemData> items, bool isVN) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // Chia làm 2 cột
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.75, // Tỷ lệ chiều rộng / chiều cao của thẻ
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Khu vực hiển thị ảnh/icon minh họa vật phẩm
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.08),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Center(
                    child: Icon(item.icon, size: 50, color: item.color),
                  ),
                ),
              ),
              // Thông tin vật phẩm (Tên + Giá + Nút mua)
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Giá tiền xu
                        Row(
                          children: [
                            const Icon(Icons.monetization_on,
                                color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              "${item.price}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87),
                            ),
                          ],
                        ),
                        // Nút Mua (Tạm thời chưa xử lý logic)
                        SizedBox(
                          height: 28,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () {
                              // Tạm thời chưa có chức năng xử lý mua hàng
                            },
                            child: Text(
                              isVN ? "Mua" : "Buy",
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Model dữ liệu mẫu cho mỗi vật phẩm trong shop
class ShopItemData {
  final String id;
  final String name;
  final int price;
  final IconData icon;
  final Color color;

  ShopItemData({
    required this.id,
    required this.name,
    required this.price,
    required this.icon,
    required this.color,
  });
}
