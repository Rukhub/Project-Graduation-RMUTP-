import 'dart:io';

import 'package:flutter/material.dart';

class EquipmentImageSection extends StatelessWidget {
  final String title;
  final List<String> images;
  final Color color;
  final bool isAdmin;
  final bool isUploadingImage;
  final VoidCallback onAddImage;
  final void Function(int) onDeleteImage;
  final VoidCallback onUploadImages;
  final void Function(String imageUrl) onOpenImage;

  const EquipmentImageSection({
    super.key,
    required this.title,
    required this.images,
    required this.color,
    required this.isAdmin,
    required this.isUploadingImage,
    required this.onAddImage,
    required this.onDeleteImage,
    required this.onUploadImages,
    required this.onOpenImage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.photo_library,
                    color: Colors.grey.shade700,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  '${images.length} รูป',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          images.isEmpty
              ? EquipmentEmptyImageState(
                  onAddImage: onAddImage,
                  isAdmin: isAdmin,
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: isAdmin ? images.length + 1 : images.length,
                  itemBuilder: (context, index) {
                    if (isAdmin && index == images.length) {
                      return EquipmentAddImageButton(onAddImage: onAddImage);
                    }
                    return EquipmentImageCard(
                      images: images,
                      index: index,
                      onDelete: onDeleteImage,
                      onOpen: () => onOpenImage(images[index]),
                      isAdmin: isAdmin,
                    );
                  },
                ),
          if (images.isNotEmpty && isAdmin) ...[
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isUploadingImage ? null : onUploadImages,
                icon: isUploadingImage
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_upload, color: Colors.white),
                label: Text(
                  isUploadingImage ? 'กำลังอัปโหลด...' : 'อัปโหลดรูปภาพ',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9A2C2C),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class EquipmentEmptyImageState extends StatelessWidget {
  final VoidCallback onAddImage;
  final bool isAdmin;

  const EquipmentEmptyImageState({
    super.key,
    required this.onAddImage,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200, width: 2),
      ),
      child: Column(
        children: [
          Icon(Icons.photo_camera, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 15),
          Text(
            'ยังไม่มีรูปภาพ',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'กดปุ่มด้านล่างเพื่อเพิ่มรูป',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 20),
          if (isAdmin)
            ElevatedButton.icon(
              onPressed: onAddImage,
              icon: const Icon(Icons.add_photo_alternate, color: Colors.white),
              label: const Text(
                'เพิ่มรูปภาพ',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9A2C2C),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class EquipmentAddImageButton extends StatelessWidget {
  final VoidCallback onAddImage;

  const EquipmentAddImageButton({
    super.key,
    required this.onAddImage,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onAddImage,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF9A2C2C).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF9A2C2C).withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: const Icon(
          Icons.add_photo_alternate,
          color: Color(0xFF9A2C2C),
          size: 40,
        ),
      ),
    );
  }
}

class EquipmentImageCard extends StatelessWidget {
  final List<String> images;
  final int index;
  final void Function(int) onDelete;
  final VoidCallback onOpen;
  final bool isAdmin;

  const EquipmentImageCard({
    super.key,
    required this.images,
    required this.index,
    required this.onDelete,
    required this.onOpen,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: onOpen,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: images[index].startsWith('http')
                    ? NetworkImage(images[index])
                    : FileImage(File(images[index])) as ImageProvider,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        if (isAdmin)
          Positioned(
            top: 5,
            right: 5,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.8),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                onPressed: () => onDelete(index),
              ),
            ),
          ),
      ],
    );
  }
}
