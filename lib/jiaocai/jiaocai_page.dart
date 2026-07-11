import 'package:flutter/material.dart';
import 'package:cue/cue.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:smooth_dropdown/smooth_dropdown.dart';

import '../core/http_client.dart';
import '../core/data_cache.dart';
import '../core/smooth_styles.dart';
import 'jiaocai.dart';
import 'jiaocai_service.dart';

const Color _yibinBlue = Color.fromRGBO(25, 25, 153, 1);

class JiaocaiPage extends StatefulWidget {
  final SharedHttpClient client;
  final String? userId;

  const JiaocaiPage({super.key, required this.client, this.userId});

  @override
  State<JiaocaiPage> createState() => _JiaocaiPageState();
}

class _JiaocaiPageState extends State<JiaocaiPage> {
  List<TextbookOrder>? _orders;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orders = await JiaocaiService(widget.client,
              studentId: widget.userId).fetchOrders();
      if (mounted) {
        setState(() {
          _orders = orders;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('教材查询'),
          centerTitle: true,
          actions: [
            if (_orders != null)
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                onPressed: () {
                  DataCache().invalidate('jiaocai_orders');
                  _fetch();
                },
                tooltip: '刷新',
              ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null) {
      return _buildError();
    }
    if (_orders == null || _orders!.isEmpty) {
      return Center(
        child: Text('暂无教材订购记录',
            style: TextStyle(fontSize: 14, color: Colors.grey[400])),
      );
    }
    // 取第一个有信息的记录展示个人信息
    final info = _orders!.firstWhere(
      (o) => o.grade.isNotEmpty || o.major.isNotEmpty || o.className.isNotEmpty,
      orElse: () => _orders!.first,
    );

    return RefreshIndicator(
      onRefresh: () async {
        DataCache().invalidate('jiaocai_orders');
        await _fetch();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          // 个人信息卡片
          _buildInfoCard(info),
          const SizedBox(height: 16),
          // 各学期卡片
          ..._orders!.asMap().entries.map(
              (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _buildOrderCard(e.value, e.key),
                  )),
        ],
      ),
    );
  }

  Widget _buildInfoCard(TextbookOrder info) {
    return Cue.onMount(
      motion: .smooth(),
      acts: [.fadeIn(), .slideY(from: 0.08)],
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: _yibinBlue.withValues(alpha: 0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _yibinBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.person_rounded,
                    color: _yibinBlue, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.userId ?? '',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    if (info.major.isNotEmpty)
                      _infoRow(Icons.school_outlined, info.major),
                    if (info.className.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _infoRow(Icons.group_outlined, info.className),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: _yibinBlue.withValues(alpha: 0.6)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 13, color: _yibinBlue.withValues(alpha: 0.8))),
        ),
      ],
    );
  }

  Widget _buildOrderCard(TextbookOrder order, int index) {
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 44,
            decoration: BoxDecoration(
              color: _yibinBlue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.semester,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${order.quantity}册 · ¥${order.totalPrice.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Cue.onMount(
      motion: .smooth(),
      child: Actor(
        delay: Duration(milliseconds: (index % 10) * 30),
        acts: [.fadeIn(), .slideY(from: 0.08)],
        child: SmoothExpansionTile(
          initiallyExpanded: false,
          style: smoothStyle(context),
          headerBuilder: (context, expand, controller) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => controller.toggle(),
            child: header,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 1, indent: 16, endIndent: 16),
              const SizedBox(height: 8),
              Text('订购教材',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...order.books.map((book) => _buildBookItem(book)),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookItem(TextbookBook book) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.book_rounded, size: 16, color: Colors.grey[400]),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(book.name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                    children: [
                      TextSpan(text: 'ISBN: ${book.isbn}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('¥${book.price.toStringAsFixed(1)}',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _yibinBlue)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('获取失败',
                style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('重试'),
              onPressed: () {
                DataCache().invalidate('jiaocai_orders');
                _fetch();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _yibinBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
