import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../news/webview_page.dart';

const Color _yibinBlue = Color.fromRGBO(25, 25, 153, 1);

class _Unit {
  final String name;
  final String url;
  const _Unit(this.name, this.url);
}

const List<_Unit> _units = [
  _Unit('教师教育学院/教育科学学院', 'https://jykx.yibinu.edu.cn/'),
  _Unit('数理学院', 'https://lxb.yibinu.edu.cn/'),
  _Unit('材料与化学工程学院', 'https://chxb.yibinu.edu.cn/'),
  _Unit('计算机科学与技术学院（人工智能学院）', 'https://jsjxy.yibinu.edu.cn/'),
  _Unit('电子信息工程学院', 'https://dzxx.yibinu.edu.cn/'),
  _Unit('机械与电气工程学院', 'https://jxdq.yibinu.edu.cn/'),
  _Unit('文学与新闻传媒学院', 'https://wxxb.yibinu.edu.cn/'),
  _Unit('外国语学院', 'https://gjjy.yibinu.edu.cn/'),
  _Unit('经济与工商管理学院', 'http://feba.yibinu.edu.cn/'),
  _Unit('法学与公共管理学院', 'https://fgxb.yibinu.edu.cn/'),
  _Unit('马克思主义学院', 'https://mkszy.yibinu.edu.cn/'),
  _Unit('音乐与舞蹈学院', 'https://yyby.yibinu.edu.cn/'),
  _Unit('艺术设计学院', 'https://ycxb.yibinu.edu.cn/'),
  _Unit('体育与大健康学院', 'https://pe.yibinu.edu.cn/'),
  _Unit('农林与食品工程学部', 'https://ccxy.yibinu.edu.cn/'),
  _Unit('质量管理与检验检测学部', 'https://zj.yibinu.edu.cn/'),
];

class UnitsPage extends StatelessWidget {
  const UnitsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('教学单位'),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            for (final unit in _units) ...[
              _buildUnitCard(context, unit),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: _yibinBlue.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _yibinBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.school_rounded,
                  color: _yibinBlue, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('宜宾学院教学单位',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('共 ${_units.length} 个学院/学部',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitCard(BuildContext context, _Unit unit) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _yibinBlue.withValues(alpha: 0.08)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (unit.url.startsWith('http')) {
            launchUrl(Uri.parse(unit.url),
                mode: LaunchMode.externalApplication);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      WebViewPage(url: unit.url, title: unit.name)),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _yibinBlue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    unit.name[0],
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _yibinBlue,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(unit.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
              ),
              Icon(Icons.open_in_new_rounded,
                  size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
