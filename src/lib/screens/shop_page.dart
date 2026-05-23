import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:esstudy/constants/colors.dart';
import 'package:esstudy/constants/var.dart';

class ShopPage extends StatefulWidget {
  final String userId;

  const ShopPage({super.key, required this.userId});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  bool _isProcessing = false;

  Future<void> _processPurchase(
    ShopItemData item,
    bool isVN,
    bool isOwned,
    int currentCoins,
  ) async {
    if (_isProcessing) return;

    HapticFeedback.lightImpact();

    setState(() {
      _isProcessing = true;
    });

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(widget.userId);

    try {
      if (isOwned) {
        // --- 1. LUỒNG TRANG BỊ (Khi đã sở hữu) ---
        if (item.type == ItemType.background) {
          await userRef.update({'bannerUrl': item.value});
        } else if (item.type == ItemType.avatar) {
          await userRef.update({'avatarUrl': item.value});
        } else {
          await userRef.update({'activeEffect': item.value});
        }

        if (!mounted) return;

        // Vẫn giữ SnackBar cho thao tác trang bị để nó diễn ra nhanh gọn
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              backgroundColor: Colors.blue,
              content: Text(
                isVN
                    ? 'Đã trang bị: ${item.name} 🎒'
                    : 'Equipped: ${item.name} 🎒',
              ),
            ),
          );

        return;
      }

      // --- 2. LUỒNG MUA HÀNG (Chưa sở hữu) ---
      if (currentCoins < item.price) {
        if (!mounted) return;

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text(
                isVN ? 'Bạn không đủ xu rồi!' : 'Not enough coins!',
              ),
            ),
          );

        return;
      }

      // CHỈ trừ tiền và thêm vào kho (KHÔNG tự động cập nhật banner/avatar đang dùng)
      Map<String, dynamic> updates = {
        'coin': FieldValue.increment(-item.price),
      };

      if (item.type == ItemType.background) {
        updates['ownedBanners'] = FieldValue.arrayUnion([item.value]);
      } else if (item.type == ItemType.avatar) {
        updates['ownedAvatars'] = FieldValue.arrayUnion([item.value]);
      } else {
        updates['ownedEffects'] = FieldValue.arrayUnion([item.value]);
      }

      await userRef.update(updates);

      if (!mounted) return;

      // HIỂN THỊ POPUP CHÚC MỪNG MUA THÀNH CÔNG
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                const Icon(Icons.celebration, color: Colors.orange, size: 28),
                const SizedBox(width: 10),
                Text(
                  isVN ? 'Thành công!' : 'Success!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Text(
              isVN
                  ? 'Chúc mừng bạn đã mua "${item.name}" thành công!'
                  : 'Congratulations on purchasing "${item.name}"!',
              style: const TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  isVN ? 'Đóng' : 'Close',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      debugPrint('Purchase error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isVN = languageNotifier.value == 'Tiếng Việt';

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final data = (snapshot.data!.data() ?? {}) as Map<String, dynamic>;

        int coins = data['coin'] ?? 0;

        List<String> ownedAvatars =
            List<String>.from(data['ownedAvatars'] ?? []);

        List<String> ownedBanners =
            List<String>.from(data['ownedBanners'] ?? []);

        List<String> ownedEffects =
            List<String>.from(data['ownedEffects'] ?? []);

        String activeAvatar = data['avatarUrl'] ?? '';
        String activeBanner = data['bannerUrl'] ?? '';
        String activeEffect = data['activeEffect'] ?? '';

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            backgroundColor: Colors.grey.shade50,
            appBar: AppBar(
              elevation: 0,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              title: Text(
                isVN ? 'Cửa hàng vật phẩm' : 'Item Shop',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.monetization_on,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '$coins',
                        style: TextStyle(
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              bottom: TabBar(
                indicatorColor: primaryColor,
                labelColor: primaryColor,
                unselectedLabelColor: Colors.grey,
                tabs: [
                  Tab(text: isVN ? 'Nền' : 'Backgrounds'),
                  Tab(text: isVN ? 'Avatar' : 'Avatars'),
                  Tab(text: isVN ? 'Hiệu ứng' : 'Effects'),
                ],
              ),
            ),
            body: TabBarView(
              physics: const BouncingScrollPhysics(),
              children: [
                _buildShopGrid(
                  backgroundItems(isVN),
                  isVN,
                  coins,
                  ownedBanners,
                  ownedAvatars,
                  ownedEffects,
                  activeBanner,
                  activeAvatar,
                  activeEffect,
                ),
                _buildShopGrid(
                  avatarItems(isVN),
                  isVN,
                  coins,
                  ownedBanners,
                  ownedAvatars,
                  ownedEffects,
                  activeBanner,
                  activeAvatar,
                  activeEffect,
                ),
                _buildShopGrid(
                  effectItems(isVN),
                  isVN,
                  coins,
                  ownedBanners,
                  ownedAvatars,
                  ownedEffects,
                  activeBanner,
                  activeAvatar,
                  activeEffect,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShopGrid(
    List<ShopItemData> items,
    bool isVN,
    int currentCoins,
    List<String> ownedBanners,
    List<String> ownedAvatars,
    List<String> ownedEffects,
    String activeBanner,
    String activeAvatar,
    String activeEffect,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      cacheExtent: 1200,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.70,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];

        bool isOwned = false;
        bool isEquipped = false;

        if (item.type == ItemType.background) {
          isOwned = ownedBanners.contains(item.value);
          isEquipped = activeBanner == item.value;
        } else if (item.type == ItemType.avatar) {
          isOwned = ownedAvatars.contains(item.value);
          isEquipped = activeAvatar == item.value;
        } else {
          isOwned = ownedEffects.contains(item.value);
          isEquipped = activeEffect == item.value;
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.08),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(22),
                    ),
                  ),
                  child: Center(
                    child: item.type == ItemType.background
                        ? Icon(
                            item.icon,
                            size: 52,
                            color: item.color,
                          )
                        : CachedNetworkImage(
                            imageUrl: item.value,
                            fit: BoxFit.contain,
                            memCacheWidth: 300,
                            fadeInDuration: const Duration(milliseconds: 150),
                            placeholder: (context, url) =>
                                CircularProgressIndicator(
                              color: item.color,
                            ),
                            errorWidget: (context, url, error) => Icon(
                              item.icon,
                              size: 50,
                              color: item.color,
                            ),
                          ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (!isOwned)
                          Row(
                            children: [
                              const Icon(
                                Icons.monetization_on,
                                color: Colors.amber,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${item.price}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                        else if (isEquipped)
                          Text(
                            isVN ? 'Đang dùng' : 'Equipped',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          )
                        else
                          Text(
                            isVN ? 'Đã sở hữu' : 'Owned',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        AnimatedScale(
                          scale: _isProcessing ? 0.96 : 1,
                          duration: const Duration(milliseconds: 120),
                          child: SizedBox(
                              height: 30,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isEquipped
                                      ? Colors.green
                                      : (isOwned ? Colors.blue : primaryColor),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  // 1. Giảm padding hai bên xuống tối thiểu và làm nút mỏng lại
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 6),
                                  minimumSize: const Size(50, 32),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () => _processPurchase(
                                    item, isVN, isOwned, currentCoins),
                                // 2. Dùng FittedBox để đảm bảo chữ luôn vừa vặn trong nút, không bị rớt dòng
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    isEquipped
                                        ? (isVN
                                            ? "Đã dùng"
                                            : "Equipped") // 3. Rút gọn chữ thành "Đã dùng"
                                        : (isOwned
                                            ? (isVN ? "Dùng" : "Equip")
                                            : (isVN ? "Mua" : "Buy")),
                                    style: const TextStyle(
                                      fontSize:
                                          11, // 4. Hạ size chữ một chút cho thanh thoát
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              )),
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

enum ItemType {
  background,
  avatar,
  effect,
}

class ShopItemData {
  final String id;
  final String name;
  final int price;
  final String value;
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

List<ShopItemData> backgroundItems(bool isVN) {
  return [
    ShopItemData(
      id: 'bg_blue',
      name: isVN ? 'Nền Xanh Thanh Lịch' : 'Elegant Blue',
      price: 200,
      value: 'https://images.unsplash.com/photo-1557683316-973673baf926',
      icon: Icons.wallpaper,
      type: ItemType.background,
      color: Colors.blue,
    ),
    ShopItemData(
      id: 'bg_nature',
      name: isVN ? 'Nền Rừng Xanh' : 'Deep Nature',
      price: 250,
      value: 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e',
      icon: Icons.forest,
      type: ItemType.background,
      color: Colors.green,
    ),
    ShopItemData(
      id: 'bg_stars',
      name: isVN ? 'Bầu Trời Đêm' : 'Night Sky',
      price: 350,
      value: 'https://images.unsplash.com/photo-1519681393784-d120267933ba',
      icon: Icons.star_border,
      type: ItemType.background,
      color: Colors.deepPurple,
    ),
    ShopItemData(
      id: 'bg_matrix',
      name: isVN ? 'Không Gian Số' : 'Cyber Matrix',
      price: 400,
      value: 'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5',
      icon: Icons.data_object,
      type: ItemType.background,
      color: Colors.teal,
    ),
    ShopItemData(
      id: 'bg_sunset',
      name: isVN ? 'Hoàng Hôn Đỏ' : 'Red Sunset',
      price: 500,
      value: 'https://images.unsplash.com/photo-1502134249126-9f3755a50d78',
      icon: Icons.wb_twilight,
      type: ItemType.background,
      color: Colors.deepOrange,
    ),
  ];
}

List<ShopItemData> avatarItems(bool isVN) {
  return [
    ShopItemData(
      id: 'av_bot',
      name: isVN ? 'Rô-bốt' : 'Robot',
      price: 300,
      value: 'https://cdn-icons-png.flaticon.com/512/4712/4712035.png',
      icon: Icons.android,
      type: ItemType.avatar,
      color: Colors.teal,
    ),
    ShopItemData(
      id: 'av_cat',
      name: isVN ? 'Mèo Ú' : 'Chubby Cat',
      price: 300,
      value: 'https://cdn-icons-png.flaticon.com/512/616/616430.png',
      icon: Icons.pets,
      type: ItemType.avatar,
      color: Colors.brown,
    ),
    ShopItemData(
      id: 'av_star',
      name: isVN ? 'Ngôi Sao' : 'Star Talent',
      price: 300,
      value: 'https://cdn-icons-png.flaticon.com/512/1828/1828884.png',
      icon: Icons.auto_awesome,
      type: ItemType.avatar,
      color: Colors.amber,
    ),
    ShopItemData(
      id: 'av_astro',
      name: isVN ? 'Học tập' : 'Study',
      price: 300,
      value: 'https://cdn-icons-png.flaticon.com/512/825/825590.png',
      icon: Icons.rocket_launch,
      type: ItemType.avatar,
      color: Colors.indigo,
    ),
    ShopItemData(
      id: 'av_dev',
      name: isVN ? 'Lập trình viên' : 'Developer',
      price: 500,
      value: 'https://cdn-icons-png.flaticon.com/512/1183/1183672.png',
      icon: Icons.terminal,
      type: ItemType.avatar,
      color: Colors.blueGrey,
    ),
    ShopItemData(
      id: 'av_monster',
      name: isVN ? 'Gấu Koala' : 'Koala Buddy',
      price: 500,
      value: 'https://cdn-icons-png.flaticon.com/512/3069/3069172.png',
      icon: Icons.smart_toy,
      type: ItemType.avatar,
      color: Colors.lightGreen,
    ),
    ShopItemData(
      id: 'av_tiger',
      name: isVN ? 'Mãnh hổ' : 'Tiger',
      price: 500,
      value: 'https://cdn-icons-png.flaticon.com/512/3069/3069173.png',
      icon: Icons.smart_toy,
      type: ItemType.avatar,
      color: Colors.lightGreen,
    ),
    ShopItemData(
      id: 'av_peacock',
      name: isVN ? 'Ong chăm chỉ' : 'Diligent Bee',
      price: 1000,
      value: 'https://cdn-icons-png.flaticon.com/512/3069/3069171.png',
      icon: Icons.pets,
      type: ItemType.avatar,
      color: Colors.blueAccent,
    ),
    ShopItemData(
      id: 'av_knight',
      name: isVN ? 'Bảo mật' : 'Security',
      price: 500,
      value: 'https://cdn-icons-png.flaticon.com/512/3408/3408455.png',
      icon: Icons.shield,
      type: ItemType.avatar,
      color: Colors.red,
    ),
    ShopItemData(
      id: 'av_ninja',
      name: isVN ? 'Doanh nhân' : 'Entrepreneur',
      price: 500,
      value: 'https://cdn-icons-png.flaticon.com/512/3135/3135715.png',
      icon: Icons.sports_martial_arts,
      type: ItemType.avatar,
      color: Colors.black87,
    ),
    ShopItemData(
      id: 'av_wizard',
      name: isVN ? 'Xe buýt' : 'Bus Driver',
      price: 500,
      value: 'https://cdn-icons-png.flaticon.com/512/1042/1042318.png',
      icon: Icons.auto_fix_normal,
      type: ItemType.avatar,
      color: Colors.purple,
    ),
    ShopItemData(
      id: 'av_detective',
      name: isVN ? 'Giàu có' : 'Wealthy',
      price: 1000,
      value: 'https://cdn-icons-png.flaticon.com/512/4836/4836932.png',
      icon: Icons.search,
      type: ItemType.avatar,
      color: Colors.brown,
    ),
  ];
}

List<ShopItemData> effectItems(bool isVN) {
  return [
    // FIREWORK
    ShopItemData(
      id: 'firework',
      name: isVN ? 'Hiệu ứng Pháo Hoa' : 'Fireworks',
      price: 1000,
      value: 'firework',
      icon: Icons.celebration,
      type: ItemType.effect,
      color: Colors.redAccent,
    ),

    // SNOW
    ShopItemData(
      id: 'snow',
      name: isVN ? 'Hiệu ứng Người tuyết' : 'Snow Effect',
      price: 1000,
      value: 'snow',
      icon: Icons.ac_unit,
      type: ItemType.effect,
      color: Colors.lightBlueAccent,
    ),

    // SPARKLE
    ShopItemData(
      id: 'sparkle',
      name: isVN ? 'Hiệu ứng Lấp Lánh' : 'Sparkle Effect',
      price: 1000,
      value: 'sparkle',
      icon: Icons.auto_awesome,
      type: ItemType.effect,
      color: Colors.amber,
    ),
  ];
}
