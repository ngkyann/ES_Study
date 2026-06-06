import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:esstudy/constants/var.dart';
import 'package:rich_text_controller/rich_text_controller.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 🔥 Thêm thư viện lưu tạm
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:markdown/markdown.dart' as md;

class QuickNoteDialog extends StatefulWidget {
  final String userId;
  final bool isVN;
  const QuickNoteDialog({super.key, required this.userId, required this.isVN});

  @override
  State<QuickNoteDialog> createState() => _QuickNoteDialogState();
}

class _QuickNoteDialogState extends State<QuickNoteDialog> {
  late final RichTextController _noteController;
  final TextEditingController _titleController = TextEditingController();
  bool _isAiLoading = false;
  bool _isChanged = true;
  bool _isPreviewMode = false;
  @override
  void initState() {
    super.initState();

    _noteController = RichTextController(
      targetMatches: [
        MatchTargetItem(
          regex: RegExp(r'\*\*.*?\*\*'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        MatchTargetItem(
          regex: RegExp(r'(?<!\*)\*[^*]+\*(?!\*)'),
          style: const TextStyle(
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
      onMatch: (List<String> matches) {
        debugPrint("Đã nhận diện các đoạn text định dạng: $matches");
      },
    );

    // 🔥 Gọi hàm khôi phục dữ liệu tạm khi vừa mở Pop-up lên
    _loadDraftNote();

    // Lắng nghe sự thay đổi nội dung
    _noteController.addListener(() {
      if (!_isChanged) {
        _isChanged = true;
      }
      // 🔥 Mỗi khi người dùng gõ thêm chữ, tự động lưu tạm xuống máy luôn
      _saveDraftNote(_noteController.text);
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  // 🔥 HÀM 1: Tự động lưu tạm văn bản xuống bộ nhớ máy
  Future<void> _saveDraftNote(String text) async {
    final prefs = await SharedPreferences.getInstance();
    // Lưu theo userId để tránh việc tài khoản này đọc nhầm note tạm của tài khoản khác
    await prefs.setString('draft_note_${widget.userId}', text);
  }

  // 🔥 HÀM 2: Khôi phục lại văn bản tạm khi mở app/popup lên
  Future<void> _loadDraftNote() async {
    final prefs = await SharedPreferences.getInstance();
    final draft = prefs.getString('draft_note_${widget.userId}');
    if (draft != null && draft.isNotEmpty && mounted) {
      setState(() {
        _noteController.text = draft;
        _isChanged = true; // Cho phép AI xử lý tiếp text tạm này nếu muốn
        _isPreviewMode = true;
      });
    }
  }

  // 🔥 HÀM 3: Xóa bỏ bản nháp lưu tạm khi đã lưu lên Database thành công
  Future<void> _clearDraftNote() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('draft_note_${widget.userId}');
  }

  void _showUnchangedPopup() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.orange, size: 28),
            const SizedBox(width: 10),
            Text(
              widget.isVN ? "Thông báo" : "Notice",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          widget.isVN
              ? "Nội dung không đổi, hãy chỉnh sửa thêm trước khi tối ưu lại bằng AI!"
              : "Content unchanged, please edit before optimizing with AI again!",
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              widget.isVN ? "Đã hiểu" : "Got it",
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processAiNote() async {
    final text = _noteController.text.trim();
    if (text.isEmpty) return;

    if (!_isChanged) {
      _showUnchangedPopup();
      return;
    }

    setState(() => _isAiLoading = true);

    try {
      final model = GenerativeModel(
        model: 'gemini-3.1-flash-lite',
        apiKey: geminiApiKey,
        requestOptions: const RequestOptions(apiVersion: 'v1'),
      );

      final prompt = """
Bạn là một trợ lý ghi chú học tập thông minh. 
Nhiệm vụ của bạn là đọc đoạn ghi chú thô dưới đây của học sinh, tiến hành TỈNH LƯỢC (bỏ từ thừa, giữ từ khóa) và TỰ PHÂN CẤP cấu trúc (dạng danh sách bullet points) để dễ nhìn, dễ học thuộc nhất.
Đầu ra CHỈ trả về đoạn văn bản đã xử lý xong viết dưới định dạng Markdown đẹp mắt, có thể sử dụng biểu thức LaTeX nếu cần ghi công thức toán/lý/hóa. Không chào hỏi, không giải thích dài dòng.

Nội dung ghi chú thô:
"$text"
""";

      final response = await model.generateContent([Content.text(prompt)]);
      final aiResult = response.text;

      if (aiResult != null && mounted) {
        setState(() {
          _noteController.text = aiResult.trim();
          _isChanged = false;
          _isPreviewMode = true;
        });
        // 🔥 Lưu tạm kết quả AI trả về vào máy phòng khi người dùng tắt ngang
        _saveDraftNote(_noteController.text);
      }
    } catch (e) {
      debugPrint("Lỗi AI Note: $e");
    } finally {
      if (mounted) setState(() => _isAiLoading = false);
    }
  }

  Future<void> _saveNote() async {
    if (_noteController.text.trim().isEmpty) return;

    String currentTitle = _titleController.text.trim();
    if (currentTitle.isEmpty) {
      currentTitle = "Note ${DateTime.now().day}/${DateTime.now().month}";
    }

    _titleController.text = currentTitle;

    bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.bookmark_add_rounded, color: primaryColor, size: 26),
            const SizedBox(width: 10),
            Text(
              widget.isVN ? "Đặt tên ghi chú" : "Note Title",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: TextField(
          controller: _titleController,
          decoration: InputDecoration(
            hintText: widget.isVN ? "Nhập tiêu đề..." : "Enter title...",
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: primaryColor)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(widget.isVN ? "Hủy" : "Cancel",
                style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              widget.isVN ? "Lưu" : "Save",
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await FirebaseFirestore.instance.collection('quick_notes').add({
          'userId': widget.userId,
          'title': _titleController.text.trim(),
          'content': _noteController.text.trim(),
          'timestamp': FieldValue.serverTimestamp(),
        });

        // 🔥 Xóa bản lưu tạm đi vì đã lưu chính thức thành công lên đám mây Cloud Firestore
        await _clearDraftNote();

        if (mounted) {
          showDialog(
            context: context,
            builder: (successCtx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.green, size: 50),
                  const SizedBox(height: 15),
                  Text(
                    widget.isVN ? "Đã lưu thành công!" : "Saved successfully!",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              actions: [
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(successCtx),
                    child: Text(widget.isVN ? "Đóng" : "Close",
                        style: TextStyle(color: primaryColor)),
                  ),
                )
              ],
            ),
          );
        }
      } catch (e) {
        debugPrint("Lỗi lưu note: $e");
      }
    }
  }

  Future<bool?> _deleteNote(String docId) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded,
                color: Colors.redAccent, size: 26),
            const SizedBox(width: 10),
            Text(widget.isVN ? "Xóa ghi chú" : "Delete Note",
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(widget.isVN
            ? "Bạn có chắc chắn muốn xóa ghi chú này không?"
            : "Are you sure you want to delete this note?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(widget.isVN ? "Hủy" : "Cancel",
                style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              widget.isVN ? "Xóa" : "Delete",
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadNotesList() async {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.folder_open_rounded,
                  color: Colors.orange, size: 26),
              const SizedBox(width: 10),
              Text(
                widget.isVN ? "Chọn ghi chú đã lưu" : "Select saved note",
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.7,
            height: MediaQuery.of(context).size.height * 0.45,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('quick_notes')
                  .where('userId', isEqualTo: widget.userId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                        widget.isVN ? "Chưa có ghi chú nào" : "No notes found",
                        style: TextStyle(color: Colors.grey.shade500)),
                  );
                }

                final sortedDocs = List.from(docs);
                sortedDocs.sort((a, b) {
                  final aTime = (a.data() as Map<String, dynamic>)['timestamp']
                      as Timestamp?;
                  final bTime = (b.data() as Map<String, dynamic>)['timestamp']
                      as Timestamp?;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });

                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: sortedDocs.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final doc = sortedDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      leading: const Icon(Icons.article_rounded,
                          color: Colors.amber, size: 28),
                      title: Text(
                        data['title'] ?? 'Untitled',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        data['content'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: Colors.redAccent, size: 20),
                        onPressed: () async {
                          bool? deleteConfirm = await _deleteNote(doc.id);
                          if (deleteConfirm == true) {
                            await FirebaseFirestore.instance
                                .collection('quick_notes')
                                .doc(doc.id)
                                .delete();
                          }
                        },
                      ),
                      onTap: () {
                        setState(() {
                          _titleController.text = data['title'] ?? '';
                          _noteController.text = data['content'] ?? '';
                          _isChanged = true;
                          _isPreviewMode = true;
                        });
                        // 🔥 Lưu tạm ghi chú cũ vừa load này xuống máy luôn phòng khi thoát ra
                        _saveDraftNote(_noteController.text);
                        Navigator.pop(dialogCtx);
                      },
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(widget.isVN ? "Đóng" : "Close",
                  style: TextStyle(color: primaryColor)),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: size.width * 0.78,
          height: size.height * 0.65,
          decoration: BoxDecoration(
            color: const Color(0xFFFFFDF0),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 2,
              )
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: 16.0, right: 8.0, top: 12.0, bottom: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.edit_note, color: primaryColor, size: 22),
                          const SizedBox(width: 6),
                          Text(
                            widget.isVN ? "Sổ tay nhanh" : "Quick Note",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.close,
                                color: Colors.grey, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Divider(
                          color: Colors.amber, thickness: 1.5, height: 1),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _isAiLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _isPreviewMode
                                // 👉 THÊM ĐOẠN NÀY: Giao diện hiển thị Markdown + LaTeX
                                ? Markdown(
                                    data: _noteController.text,
                                    selectable: true,
                                    padding: EdgeInsets
                                        .zero, // Giúp căn lề khớp với giao diện TextField cũ
                                    builders: {
                                      // 👉 SỬA LẠI ĐOẠN NÀY
                                      'latex': LatexElementBuilder(),
                                    },
                                    extensionSet: md.ExtensionSet(
                                      [
                                        LatexBlockSyntax(),
                                        ...md.ExtensionSet.gitHubFlavored
                                            .blockSyntaxes
                                      ],
                                      [
                                        LatexInlineSyntax(),
                                        ...md.ExtensionSet.gitHubFlavored
                                            .inlineSyntaxes
                                      ],
                                    ),
                                    styleSheet: MarkdownStyleSheet(
                                      p: const TextStyle(
                                          fontSize: 14,
                                          height: 1.5,
                                          color: Colors.black87),
                                      listBullet: const TextStyle(
                                          fontSize: 14, color: Colors.black87),
                                    ),
                                  )
                                : TextField(
                                    controller: _noteController,
                                    maxLines: null,
                                    textAlignVertical: TextAlignVertical.top,
                                    keyboardType: TextInputType.multiline,
                                    decoration: InputDecoration(
                                      hintText: widget.isVN
                                          ? "Ghi chú nhanh kiến thức tại đây..."
                                          : "Jot down something quickly...",
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    style: const TextStyle(
                                      fontFamily: 'Courier',
                                      fontSize: 14,
                                      height: 1.4,
                                      color: Colors.black87,
                                    ),
                                  ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: 50,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _NoteSideButton(
                      icon: Icons.save_rounded,
                      label: widget.isVN ? "Lưu" : "Save",
                      color: Colors.blue,
                      onTap: _saveNote,
                    ),
                    _NoteSideButton(
                      icon: Icons.file_download_rounded,
                      label: widget.isVN ? "Tải" : "Load",
                      color: Colors.orange,
                      onTap: _loadNotesList,
                    ),
                    _NoteSideButton(
                      icon: _isPreviewMode
                          ? Icons.edit_document
                          : Icons.menu_book_rounded,
                      label: _isPreviewMode
                          ? (widget.isVN ? "Sửa" : "Edit")
                          : (widget.isVN ? "Xem" : "View"),
                      color: Colors.teal,
                      onTap: () {
                        setState(() {
                          _isPreviewMode = !_isPreviewMode;
                        });
                      },
                    ),
                    _NoteSideButton(
                      icon: Icons.auto_awesome,
                      label: "AI",
                      color: Colors.purple,
                      onTap: _processAiNote,
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteSideButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _NoteSideButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
