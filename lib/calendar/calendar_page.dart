import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

import 'calendar.dart';
import 'calendar_service.dart';
import '../core/navigation.dart';
import '../core/theme_utils.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final CalendarService _service = CalendarService();
  List<CalendarEntry>? _entries;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCalendars();
  }

  Future<void> _loadCalendars() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final entries = await _service.fetchCalendarList();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('校历服务'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCalendars,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('获取校历失败',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadCalendars,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (_entries == null || _entries!.isEmpty) {
      return const Center(
        child: Text('暂无校历数据', style: TextStyle(fontSize: 16)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCalendars,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _entries!.length,
        itemBuilder: (context, index) => _buildAnimatedCard(index),
      ),
    );
  }

  Widget _buildAnimatedCard(int index) {
    return _DelayedFadeSlide(
      delay: Duration(milliseconds: index * 50),
      child: _buildCalendarCard(_entries![index]),
    );
  }

  Widget _buildCalendarCard(CalendarEntry entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openDetail(entry),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧学年标识
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    entry.academicYear.isNotEmpty
                        ? entry.academicYear.substring(2, 4)
                        : '??',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // 右侧信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 14, color: textSecondary(context)),
                        const SizedBox(width: 4),
                        Text(
                          entry.publishDate.isNotEmpty
                              ? '发布: ${entry.publishDate}'
                              : '',
                          style: TextStyle(
                              fontSize: 12, color: textSecondary(context)),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.picture_as_pdf,
                            size: 14, color: Colors.red[300]),
                        const SizedBox(width: 4),
                        Text('PDF',
                            style: TextStyle(
                                fontSize: 12, color: Colors.red[300])),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: textHint(context)),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail(CalendarEntry entry) {
    pushPage(
      context,
      CalendarDetailPage(
        entry: entry,
        service: _service,
      ),
    );
  }
}

/// 校历详情页 - 显示 PDF 预览和下载
class CalendarDetailPage extends StatefulWidget {
  final CalendarEntry entry;
  final CalendarService service;

  const CalendarDetailPage({
    super.key,
    required this.entry,
    required this.service,
  });

  @override
  State<CalendarDetailPage> createState() => _CalendarDetailPageState();
}

class _CalendarDetailPageState extends State<CalendarDetailPage> {
  CalendarDetail? _detail;
  bool _isLoading = true;
  String? _error;
  ImageProvider? _previewImage;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final detail = await widget.service.fetchCalendarDetail(widget.entry);
      if (!mounted) return;

      // 如果有预览图片，预加载
      ImageProvider? image;
      final previewUrl = detail.previewImageUrl;
      if (previewUrl != null && previewUrl.isNotEmpty) {
        try {
          image = NetworkImage(previewUrl);
          // 预加载
          await precacheImage(image, context);
        } catch (_) {}
      }

      setState(() {
        _detail = detail;
        _previewImage = image;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.entry.academicYear.isNotEmpty
              ? '${widget.entry.academicYear} 校历'
              : '校历详情',
          style: const TextStyle(fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
      bottomNavigationBar: _detail != null ? _buildBottomBar() : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('加载失败',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadDetail,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (_detail == null) {
      return const Center(child: Text('暂无数据'));
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题区域
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer
                  .withValues(alpha: 0.3),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.entry.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _infoChip(Icons.calendar_today,
                        '发布日期: ${widget.entry.publishDate}'),
                    const SizedBox(width: 12),
                    _infoChip(Icons.picture_as_pdf, 'PDF 校历文件'),
                  ],
                ),
              ],
            ),
          ),

          // PDF 预览图片
          if (_previewImage != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 3.0,
                  child: Image(
                    image: _previewImage!,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        SizedBox(
                      height: 200,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image,
                                size: 48, color: textHint(context)),
                            SizedBox(height: 8),
                            Text('预览图片加载失败',
                                style: TextStyle(color: textHint(context))),
                          ],
                        ),
                      ),
                    ),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      final total = loadingProgress.expectedTotalBytes;
                      final progress = total != null
                          ? loadingProgress.cumulativeBytesLoaded / total
                          : null;
                      return SizedBox(
                        height: 300,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                  value: progress),
                              const SizedBox(height: 16),
                              Text(
                                progress != null
                                    ? '${(progress * 100).toStringAsFixed(0)}%'
                                    : '加载中...',
                                style:
                                    TextStyle(color: textHint(context)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            )
          else
            // 无预览图片时用 PDFView 渲染本地文件
            _detail!.pdfFilePath != null
                ? SizedBox(
                    height: 500,
                    child: PDFView(
                      filePath: _detail!.pdfFilePath!,
                      enableSwipe: true,
                      swipeHorizontal: false,
                      autoSpacing: true,
                      pageFling: true,
                      onError: (e) => Center(
                        child: Text('PDF 加载失败: $e'),
                      ),
                    ),
                  )
                : Container(
                    height: 200,
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark(context) ? const Color(0xFF2A2A3E) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text('PDF 文件加载中…',
                          style: TextStyle(color: textHint(context))),
                    ),
                  ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textHint(context)),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, color: textHint(context))),
        ],
      ),
    );
  }

  /// 底部操作栏：下载PDF
  Widget _buildBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // 复制链接
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('复制链接'),
                onPressed: () => _copyLink(),
              ),
            ),
            const SizedBox(width: 12),
            // 下载/打开PDF
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('下载PDF'),
                onPressed: () => _downloadPdf(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyLink() async {
    if (_detail == null) return;
    await Clipboard.setData(ClipboardData(text: _detail!.pdfUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PDF 链接已复制到剪贴板'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _downloadPdf() async {
    if (_detail == null) return;

    final url = _detail!.pdfUrl;

    try {
      if (Platform.isAndroid) {
        // Android：复制链接，提示在浏览器中下载
        await Clipboard.setData(ClipboardData(text: url));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF 链接已复制，请粘贴到浏览器中下载'),
            duration: Duration(seconds: 3),
          ),
        );
      } else if (Platform.isIOS) {
        await Clipboard.setData(ClipboardData(text: url));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF 链接已复制，请在 Safari 中打开下载'),
            duration: Duration(seconds: 3),
          ),
        );
      } else if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', url]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [url]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
      } else {
        await Clipboard.setData(ClipboardData(text: url));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('链接已复制到剪贴板')),
        );
      }
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('无法自动打开，链接已复制到剪贴板'),
        ),
      );
    }
  }
}

/// 延时淡入+上浮动画（替代原 cue 入场动画）
class _DelayedFadeSlide extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _DelayedFadeSlide({required this.child, required this.delay});

  @override
  State<_DelayedFadeSlide> createState() => _DelayedFadeSlideState();
}

class _DelayedFadeSlideState extends State<_DelayedFadeSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - _animation.value)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
