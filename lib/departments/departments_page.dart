import 'package:flutter/material.dart';

import '../news/webview_page.dart';
import '../core/navigation.dart';
import '../main.dart';
import '../core/simple_page.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';


class _Dept {
  final String name;
  final String url;
  const _Dept(this.name, this.url);
}

const List<_Dept> _departments = [
  _Dept('党委办公室/院长办公室', 'https://dwb.yibinu.edu.cn'),
  _Dept('纪委办公室/纪委纪检监察室', 'https://jw.yibinu.edu.cn'),
  _Dept('党委组织部', 'https://dwzzb.yibinu.edu.cn'),
  _Dept('党委宣传部/学校新闻中心', 'https://xcb.yibinu.edu.cn'),
  _Dept('党委统战部', 'https://dwtzb.yibinu.edu.cn'),
  _Dept('党委巡察办公室', 'https://xcdc.yibinu.edu.cn'),
  _Dept('党委保卫部/党委武装部/保卫处', 'https://bwc.yibinu.edu.cn'),
  _Dept('院工会', 'https://xygh.yibinu.edu.cn'),
  _Dept('院团委', 'https://tw.yibinu.edu.cn/'),
  _Dept('发展规划处/高等教育研究所', 'https://fzghc.yibinu.edu.cn/'),
  _Dept('党委教师工作部/人事处', 'https://rsc.yibinu.edu.cn'),
  _Dept('党委学生工作部/学生工作处', 'https://xsgzc.yibinu.edu.cn/'),
  _Dept('教务处/创新创业教育学院', 'https://jwc.yibinu.edu.cn'),
  _Dept('招生就业处', 'https://zsw.yibinu.edu.cn/'),
  _Dept('党委研究生工作部/研究生工作处/学科建设处', 'https://yjsc.yibinu.edu.cn/'),
  _Dept('审计处', 'https://sjc.yibinu.edu.cn'),
  _Dept('科研处', 'https://kjc.yibinu.edu.cn/'),
  _Dept('教育教学质量评估中心', 'https://pgzx.yibinu.edu.cn'),
  _Dept('计划财务处', 'https://jhcwc.yibinu.edu.cn'),
  _Dept('国有资产与实验设备管理处', 'https://gzc.yibinu.edu.cn'),
  _Dept('国际合作与交流处/港澳台事务办公室/国际学生教育管理办公室',
      'https://international.yibinu.edu.cn'),
  _Dept('校地合作处/大学科技园管理办公室', 'https://kjy.yibinu.edu.cn'),
  _Dept('后勤管理处/后勤服务中心', 'https://zhhq.yibinu.edu.cn'),
  _Dept('基本建设处', 'https://jjc.yibinu.edu.cn'),
  _Dept('离退休人员管理处', 'https://ltc.yibinu.edu.cn'),
  _Dept('信息中心', 'https://nm.yibinu.edu.cn'),
  _Dept('图书馆/档案馆', 'https://lib.yibinu.edu.cn/'),
  _Dept('继续教育学院', 'https://cxcyxy.yibinu.edu.cn/'),
];

class DepartmentsPage extends StatelessWidget {
  const DepartmentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('职能部门'),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            for (final dept in _departments) ...[
              _buildDeptCard(context, dept),
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
        side: BorderSide(color: accentColorNotifier.value.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accentColorNotifier.value.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.business_rounded,
                  color: accentColorNotifier.value, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('宜宾学院职能部门',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('共 ${_departments.length} 个部门',
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

  Widget _buildDeptCard(BuildContext context, _Dept dept) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accentColorNotifier.value.withValues(alpha: 0.08)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => pushPage(context, WebViewPage(url: dept.url, title: dept.name)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accentColorNotifier.value.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    dept.name[0],
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: accentColorNotifier.value,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(dept.name,
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
