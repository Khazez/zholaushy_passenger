import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../config.dart';
import '../theme.dart';

/// Только показ чужого аватара (без возможности загрузки) — для карточек
/// водителя/пассажира в списках откликов, заявок, активной поездки.
class AvatarView extends StatelessWidget {
  final String? avatarUrl;
  final String initials;
  final double size;

  const AvatarView({
    super.key,
    required this.avatarUrl,
    required this.initials,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = avatarUrl != null && avatarUrl!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: hasPhoto ? null : kGradient,
        color: hasPhoto ? Colors.grey[200] : null,
        shape: BoxShape.circle,
        image: hasPhoto
            ? DecorationImage(image: NetworkImage(avatarUrl!), fit: BoxFit.cover)
            : null,
      ),
      child: !hasPhoto
          ? Center(
              child: Text(
                initials,
                style: TextStyle(color: Colors.white, fontSize: size * 0.4, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }
}

/// Круглый аватар с возможностью загрузить/сменить фото профиля.
/// Показывает инициалы, если фото ещё нет.
class AvatarPicker extends StatefulWidget {
  final String? avatarUrl;
  final String initials;
  final String token;
  final double size;
  final ValueChanged<String> onUploaded;

  const AvatarPicker({
    super.key,
    required this.avatarUrl,
    required this.initials,
    required this.token,
    required this.onUploaded,
    this.size = 96,
  });

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
    );
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: picked.name.isNotEmpty ? picked.name : 'avatar.jpg',
        ),
      });
      final res = await Dio().post(
        '$kApiBase/files/avatar',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
      );
      final url = res.data['url'] as String?;
      if (url != null) widget.onUploaded(url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось загрузить фото'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty;
    return GestureDetector(
      onTap: _uploading ? null : _pickAndUpload,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              image: hasPhoto
                  ? DecorationImage(image: NetworkImage(widget.avatarUrl!), fit: BoxFit.cover)
                  : null,
            ),
            child: !hasPhoto
                ? Center(
                    child: Text(
                      widget.initials,
                      style: TextStyle(
                        fontSize: widget.size * 0.375,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  )
                : null,
          ),
          if (_uploading)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black38),
                child: const Center(
                  child: SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  ),
                ),
              ),
            ),
          Positioned(
            right: -2, bottom: -2,
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: kTeal,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
              ),
              child: const Icon(Icons.camera_alt_rounded, size: 15, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
