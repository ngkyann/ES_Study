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
  // Hàm xử lý logic mua hàng và trang bị vật phẩm
  Future<void> _processPurchase(
      ShopItemData item, bool isVN, bool isOwned, int currentCoins) async {
    final userRef =
        FirebaseFirestore.instance.collection('users').doc(widget.userId);

    try {
      // 1. NẾU ĐÃ SỞ HỮU -> CHỈ TRANG BỊ LÊN NGƯỜI
      if (isOwned) {
        if (item.type == ItemType.background) {
          await userRef.update({'bannerUrl': item.value});
        } else if (item.type == ItemType.avatar) {
          await userRef.update({'avatarUrl': item.value});
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isVN
                ? "Đã trang bị: ${item.name} 🎒"
                : "Equipped: ${item.name} 🎒"),
            backgroundColor: Colors.blue,
          ),
        );
        return;
      }

      // 2. NẾU CHƯA SỞ HỮU -> TIẾN HÀNH THANH TOÁN
      if (currentCoins < item.price) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isVN
                ? "Bạn không đủ xu rồi! Cày thêm nhé."
                : "Not enough coins! Study more."),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      // Thực hiện trừ tiền, lưu vào kho đồ (ownedItems) và tự động mặc lên người
      Map<String, dynamic> updates = {
        'coin': FieldValue.increment(-item.price),
      };

      if (item.type == ItemType.background) {
        updates['bannerUrl'] = item.value;
        updates['ownedBanners'] = FieldValue.arrayUnion([item.value]);
      } else if (item.type == ItemType.avatar) {
        updates['avatarUrl'] = item.value;
        updates['ownedAvatars'] = FieldValue.arrayUnion([item.value]);
      }

      await userRef.update(updates);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isVN
              ? "Đã mua và trang bị: ${item.name} 🎉"
              : "Purchased and equipped: ${item.name} 🎉"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint("Lỗi mua hàng: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isVN = languageNotifier.value == "Tiếng Việt";

    // Bọc toàn bộ Scaffold bằng StreamBuilder để đồng bộ Số Xu và Trạng thái Sở hữu vật phẩm
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        int coins = 0;
        List<String> ownedAvatars = [];
        List<String> ownedBanners = [];

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          coins = data['coin'] ?? 0;
          ownedAvatars = List<String>.from(data['ownedAvatars'] ?? []);
          ownedBanners = List<String>.from(data['ownedBanners'] ?? []);
        }

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            backgroundColor: Colors.grey.shade50,
            appBar: AppBar(
              elevation: 0,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              title: Text(
                isVN ? "Cửa hàng vật phẩm" : "Item Shop",
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              actions: [
                Container(
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
                ),
              ],
              bottom: TabBar(
                labelColor: primaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: primaryColor,
                indicatorWeight: 3,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                tabs: [
                  Tab(text: isVN ? "Nền" : "Backgrounds"),
                  Tab(text: isVN ? "Avatar" : "Avatars"),
                  Tab(text: isVN ? "Hiệu ứng" : "Effects"),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                // 1. Danh mục Nền (Cập nhật thêm nhiều nền đẹp)
                _buildShopGrid(
                  [
                    ShopItemData(
                        id: "bg_blue",
                        name: isVN ? "Nền Xanh Thanh Lịch" : "Elegant Blue",
                        price: 100,
                        value:
                            "https://images.unsplash.com/photo-1557683316-973673baf926",
                        icon: Icons.wallpaper,
                        type: ItemType.background,
                        color: Colors.blue),
                    ShopItemData(
                        id: "bg_sunset",
                        name: isVN ? "Nền Hoàng Hôn" : "Sunset Glow",
                        price: 250,
                        value:
                            "https://images.unsplash.com/photo-1472120482482-d44b0e97514e",
                        icon: Icons.wb_twilight,
                        type: ItemType.background,
                        color: Colors.orange),
                    ShopItemData(
                        id: "bg_nature",
                        name: isVN ? "Nền Rừng Xanh" : "Deep Nature",
                        price: 200,
                        value:
                            "https://images.unsplash.com/photo-1441974231531-c6227db76b6e",
                        icon: Icons.forest,
                        type: ItemType.background,
                        color: Colors.green),
                    ShopItemData(
                        id: "bg_stars",
                        name: isVN ? "Bầu Trời Đêm" : "Night Sky",
                        price: 350,
                        value:
                            "https://images.unsplash.com/photo-1519681393784-d120267933ba",
                        icon: Icons.star_border,
                        type: ItemType.background,
                        color: Colors.deepPurple),
                    ShopItemData(
                        id: "bg_matrix",
                        name: isVN ? "Không Gian Số" : "Cyber Matrix",
                        price: 400,
                        value:
                            "https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5",
                        icon: Icons.data_object,
                        type: ItemType.background,
                        color: Colors.teal),
                  ],
                  isVN,
                  coins,
                  ownedBanners,
                  ownedAvatars,
                ),

                // 2. Danh mục Avatar (Bổ sung thêm một số Avatar cá tính)
                _buildShopGrid(
                  [
                    ShopItemData(
                        id: "av_bot",
                        name: isVN ? "Avatar Robot" : "Robot Avatar",
                        price: 150,
                        value:
                            "https://cdn-icons-png.flaticon.com/512/4712/4712035.png",
                        icon: Icons.android,
                        type: ItemType.avatar,
                        color: Colors.teal),
                    ShopItemData(
                        id: "av_cat",
                        name: isVN ? "Avatar Mèo Ú" : "Chubby Cat",
                        price: 200,
                        value:
                            "https://cdn-icons-png.flaticon.com/512/616/616430.png",
                        icon: Icons.pets,
                        type: ItemType.avatar,
                        color: Colors.brown),
                    ShopItemData(
                        id: "av_star",
                        name: isVN ? "Avatar Ngôi Sao" : "Star Talent",
                        price: 300,
                        value:
                            "https://cdn-icons-png.flaticon.com/512/1828/1828884.png",
                        icon: Icons.auto_awesome,
                        type: ItemType.avatar,
                        color: Colors.amber),
                    ShopItemData(
                        id: "av_astro",
                        name: isVN ? "Phi Hành Gia" : "Astronaut",
                        price: 350,
                        value:
                            "https://cdn-icons-png.flaticon.com/512/825/825590.png",
                        icon: Icons.rocket_launch,
                        type: ItemType.avatar,
                        color: Colors.indigo),
                    ShopItemData(
                        id: "av_dev",
                        name: isVN ? "Lập Trình Viên" : "Developer",
                        price: 400,
                        value:
                            "https://cdn-icons-png.flaticon.com/512/1183/1183672.png",
                        icon: Icons.terminal,
                        type: ItemType.avatar,
                        color: Colors.blueGrey),
                    ShopItemData(
                        id: "av_monster",
                        name: isVN ? "Quái Vật Xanh" : "Green Monster",
                        price: 350,
                        value:
                            "https://cdn-icons-png.flaticon.com/512/3069/3069172.png",
                        icon: Icons.smart_toy,
                        type: ItemType.avatar,
                        color: Colors.lightGreen),
                    ShopItemData(
                        id: "av_knight",
                        name: isVN ? "Hiệp Sĩ" : "Knight Gamer",
                        price: 450,
                        value:
                            "https://cdn-icons-png.flaticon.com/512/3408/3408455.png",
                        icon: Icons.shield,
                        type: ItemType.avatar,
                        color: Colors.red),
                  ],
                  isVN,
                  coins,
                  ownedBanners,
                  ownedAvatars,
                ),

                // 3. Danh mục Hiệu ứng (Giữ nguyên)
                _buildShopGrid(
                  [
                    ShopItemData(
                        id: "h1",
                        name: isVN ? "Hiệu ứng Pháo Hoa" : "Fireworks",
                        price: 500,
                        value: "firework",
                        icon: Icons.celebration,
                        type: ItemType.effect,
                        color: Colors.redAccent),
                  ],
                  isVN,
                  coins,
                  ownedBanners,
                  ownedAvatars,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Cập nhật hàm vẽ lưới để phân biệt hàng đã mua và hàng chưa mua
  Widget _buildShopGrid(
    List<ShopItemData> items,
    bool isVN,
    int currentCoins,
    List<String> ownedBanners,
    List<String> ownedAvatars,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];

        // Kiểm tra xem user đã mua vật phẩm này chưa
        bool isOwned = false;
        if (item.type == ItemType.background) {
          isOwned = ownedBanners.contains(item.value);
        } else if (item.type == ItemType.avatar) {
          isOwned = ownedAvatars.contains(item.value);
        }

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
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.08),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Center(
                    child: item.type == ItemType.background
                        ? Icon(item.icon, size: 50, color: item.color)
                        : Image.network(item.value,
                            width: 60,
                            errorBuilder: (c, e, s) =>
                                Icon(item.icon, size: 50, color: item.color)),
                  ),
                ),
              ),
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
                        // Nếu chưa sở hữu thì hiện giá tiền, ngược lại hiện chữ "Đã sở hữu"
                        if (!isOwned)
                          Row(
                            children: [
                              const Icon(Icons.monetization_on,
                                  color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                "${item.price}",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          )
                        else
                          Text(
                            isVN ? "Đã sở hữu" : "Owned",
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),

                        // Nút trạng thái Mua / Dùng
                        SizedBox(
                          height: 28,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isOwned ? Colors.blue : primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () => _processPurchase(
                                item, isVN, isOwned, currentCoins),
                            child: Text(
                              isOwned
                                  ? (isVN ? "Dùng" : "Equip")
                                  : (isVN ? "Mua" : "Buy"),
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

enum ItemType { background, avatar, effect }

class ShopItemData {
  final String id;
  final String name;
  final int price;
  final String value; // URL ảnh hoặc mã hiệu ứng
  final IconData icon;
  final Color color;
  final ItemType type;

  ShopItemData({
    required this.id,
    required this.name,
    required this.price,
    required this.value,
    required this.icon,
    required this.color,
    required this.type,
  });
}
