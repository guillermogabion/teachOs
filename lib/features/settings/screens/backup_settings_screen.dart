import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../services/backup_service.dart';
import 'package:image_picker/image_picker.dart';

class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  bool _isProcessing = false;
  bool _isRestoring = false;
  final TextEditingController _importController = TextEditingController();

  @override
  void dispose() {
    // FIXED: Properly dispose of the text controller to prevent memory leaks
    _importController.dispose();
    super.dispose();
  }

  // ── EXPORT DIALOG ──────────────────────────────────────────────────────────
  void _showBackupSuccessDialog(BuildContext context, String downloadUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _BackupLinkDialog(downloadUrl: downloadUrl),
    );
  }

  // ── IMPORT: QR SCANNER ────────────────────────────────────────────────────
  Future<void> _openQrScanner() async {
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _QrScannerScreen()),
    );
    if (scanned != null && mounted) {
      setState(() => _importController.text = scanned);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Backup & Restore')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── EXPORT SECTION ───────────────────────────────────────────
            const Text(
              'Cloud Backup',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Export your database to the cloud. Share the link or QR code to restore on another device.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_upload_rounded),
              label: Text(
                _isProcessing ? 'Uploading to Cloud...' : 'Create Cloud Backup',
              ),
              onPressed: _isProcessing
                  ? null
                  : () async {
                      setState(() => _isProcessing = true);
                      final String? url = await exportAndGetUniqueLink();
                      if (mounted) setState(() => _isProcessing = false);
                      if (url != null && mounted) {
                        _showBackupSuccessDialog(context, url);
                      } else if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Failed to backup. Please check your connection.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
            ),

            const SizedBox(height: 40),
            const Divider(),
            const SizedBox(height: 24),

            // ── IMPORT SECTION ───────────────────────────────────────────
            const Text(
              'Restore from Backup',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Paste a backup link or scan a QR code from another device.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),

            // Link input + scan button
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _importController,
                    decoration: const InputDecoration(
                      hintText: 'Paste backup link here',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Scan QR Code',
                  child: InkWell(
                    onTap: _openQrScanner,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 56,
                      width: 56,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.qr_code_scanner_rounded),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              icon: _isRestoring
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_download_rounded),
              label: Text(_isRestoring ? 'Restoring...' : 'Restore Database'),
              onPressed: _isRestoring
                  ? null
                  : () async {
                      final targetUrl = _importController.text.trim();
                      if (targetUrl.isEmpty) return;

                      setState(() => _isRestoring = true);
                      final success = await importFromLink(targetUrl);
                      if (mounted) setState(() => _isRestoring = false);

                      if (success && mounted) {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => AlertDialog(
                            title: const Text('Restore Successful'),
                            content: const Text(
                              'Database restored! Please restart the app to apply all changes.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      } else if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Restore failed. Please check the link and try again.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}

// ── BACKUP SUCCESS DIALOG: Link + QR tabs ─────────────────────────────────────
class _BackupLinkDialog extends StatefulWidget {
  final String downloadUrl;
  const _BackupLinkDialog({required this.downloadUrl});

  @override
  State<_BackupLinkDialog> createState() => _BackupLinkDialogState();
}

class _BackupLinkDialogState extends State<_BackupLinkDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return AlertDialog(
      title: const Text('Backup Successful'),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      content: SizedBox(
        width: double.maxFinite,
        height: screenHeight * 0.55,
        child: Column(
          children: [
            const Text(
              'Use the link or QR code to restore your data on another device.',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TabBar(
              controller: _tabController,
              labelColor: Colors.teal,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.teal,
              tabs: const [
                Tab(icon: Icon(Icons.link), text: 'Link'),
                Tab(icon: Icon(Icons.qr_code), text: 'QR Code'),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ── LINK TAB ──────────────────────────────────────
                  SingleChildScrollView(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SelectableText(
                              widget.downloadUrl,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: 'Copy link',
                            icon: const Icon(Icons.copy_rounded, size: 20),
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: widget.downloadUrl),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Link copied to clipboard!'),
                                  duration: Duration(seconds: 2),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── QR TAB ────────────────────────────────────────
                  Center(
                    child: QrImageView(
                      data: widget.downloadUrl,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

// ── QR SCANNER SCREEN ─────────────────────────────────────────────────────────
class _QrScannerScreen extends StatefulWidget {
  const _QrScannerScreen();

  @override
  State<_QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<_QrScannerScreen> {
  bool _scanned = false;
  final MobileScannerController _controller = MobileScannerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Helper method to safely validate if parsed text is our actual backup link configuration
  bool _isValidBackupUrl(String? url) {
    if (url == null) return false;
    // RECOMMENDED: Change this to target your specific platform url context
    // e.g., url.startsWith('https://yourdomain.site/backups/')
    return url.startsWith('http');
  }

  Future<void> _pickFromGallery() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final result = await _controller.analyzeImage(picked.path);
    if (result == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No QR code found in image.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final value = result.barcodes.firstOrNull?.rawValue;
    if (_isValidBackupUrl(value) && mounted) {
      Navigator.pop(context, value);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Invalid QR code. Please use a valid app backup QR code.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Backup QR Code'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Pick from Gallery',
            icon: const Icon(Icons.photo_library_rounded),
            onPressed: _pickFromGallery,
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_scanned) return;
              final barcode = capture.barcodes.firstOrNull;
              final value = barcode?.rawValue;
              if (_isValidBackupUrl(value)) {
                _scanned = true;
                Navigator.pop(context, value);
              }
            },
          ),

          // Scan frame overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.teal, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          // Bottom interface hints
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Point camera at QR code or pick from gallery',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('Browse Gallery'),
                  onPressed: _pickFromGallery,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
