import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/export_helper.dart' show pickFiles, openAttachment;
import '../ui/overlays.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';

/// One file attached to a record (document, customer, item, bin…).
class Attachment {
  final String name, type, by, when;
  final Uint8List bytes;
  const Attachment(this.name, this.type, this.by, this.when, this.bytes);
  int get size => bytes.length;
}

/// Files attached to each record, keyed by the record's number / code.
final attachments = <String, List<Attachment>>{};

const kMaxAttachmentBytes = 10 * 1024 * 1024; // 10 MB per file

const attachmentTypes = [
  'Supporting document', 'Purchase order copy', 'Supplier invoice', 'Customer PO', 'Delivery challan', 'Proof of delivery',
  'Quality report', 'Agreement / contract', 'GST / KYC document', 'Photo', 'Other',
];

String fileSize(int b) => b < 1024
    ? '$b B'
    : b < 1024 * 1024
        ? '${(b / 1024).toStringAsFixed(0)} KB'
        : '${(b / 1024 / 1024).toStringAsFixed(1)} MB';

String _icon(String name) {
  final e = name.split('.').last.toLowerCase();
  if (['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(e)) return 'eye';
  if (e == 'pdf') return 'file';
  return 'paperclip';
}

String _now() {
  final t = DateTime.now();
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return 'Today, ${h.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// The Attachments tab: upload files from the computer, open / download them, remove them.
class AttachmentsTab extends StatefulWidget {
  final String recordId;
  const AttachmentsTab(this.recordId, {super.key});
  @override
  State<AttachmentsTab> createState() => _AttachmentsTabState();
}

class _AttachmentsTabState extends State<AttachmentsTab> {
  String type = 'Document';
  bool busy = false;

  List<Attachment> get files => attachments.putIfAbsent(widget.recordId, () => []);

  Future<void> _upload() async {
    setState(() => busy = true);
    final picked = await pickFiles();
    if (!mounted) return;
    final tooBig = picked.where((f) => f.$2.length > kMaxAttachmentBytes).map((f) => f.$1).toList();
    final ok = picked.where((f) => f.$2.length <= kMaxAttachmentBytes).toList();
    setState(() {
      busy = false;
      for (final f in ok) {
        files.insert(0, Attachment(f.$1, type, 'Srinivas Rao', _now(), f.$2));
      }
    });
    if (tooBig.isNotEmpty) {
      toast('${tooBig.join(', ')} is larger than 10 MB and was not attached');
    } else if (ok.isNotEmpty) {
      toast(ok.length == 1 ? '${ok.first.$1} attached' : '${ok.length} files attached');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.border)),
        child: Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Btn(busy ? 'Choosing…' : 'Upload documents', icon: 'upload', onTap: busy ? null : _upload),
          const Text('PDF, image, Word, Excel or CSV · up to 10 MB each · several files at once', style: TextStyle(fontSize: 12, color: C.faint)),
        ]),
      ),
      const SizedBox(height: 14),
      if (files.isEmpty)
        const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: Empty('No documents attached yet.'))
      else
        for (final f in files)
          ActivityRow(
            _icon(f.name),
            f.name,
            '${fileSize(f.size)} · ${f.by} · ${f.when}',
            tone: Tone.gray,
            onTap: () => openAttachment(f.name, f.bytes),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconBtn('download', () => openAttachment(f.name, f.bytes), size: 30, tip: 'Open / download'),
              const SizedBox(width: 6),
              IconBtn('trash', () => confirmDelete(f.name, () {
                    setState(() => files.remove(f));
                    toast('${f.name} removed');
                  }), size: 30, tip: 'Remove'),
            ]),
          ),
    ]);
  }
}


/// Paper-clip button at the top of a record: opens its attachments; the number shows how many files are attached.
class AttachPin extends StatefulWidget {
  final String recordId;
  const AttachPin(this.recordId, {super.key});
  @override
  State<AttachPin> createState() => _AttachPinState();
}

class _AttachPinState extends State<AttachPin> {
  @override
  Widget build(BuildContext context) {
    final n = attachments[widget.recordId]?.length ?? 0;
    return Tooltip(
      message: n == 0 ? 'Attach documents' : '$n attachment(s)',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          await openModal('Attachments · ${widget.recordId}', AttachmentsTab(widget.recordId), size: ModalSize.wide,
              actions: (ctx) => [Btn('Done', onTap: () => Navigator.of(ctx).pop())]);
          if (mounted) setState(() {});
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(8), border: Border.all(color: C.border)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.attach_file, size: 17, color: C.soft),
            if (n > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: C.blue600, borderRadius: BorderRadius.circular(10)),
                child: Text('$n', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
