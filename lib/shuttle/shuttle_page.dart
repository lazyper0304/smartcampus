import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

const Color _yibinBlue = Color.fromRGBO(25, 25, 153, 1);
const Color _yibinOrange = Color.fromRGBO(230, 126, 34, 1);

/// 班次方向
enum _ShuttleDirection { toLingang, fromLingang }

/// 单个班次
class _ShuttleTrip {
  final String time;
  final _ShuttleDirection direction;

  const _ShuttleTrip(this.time, this.direction);
}

/// 所有班次
const List<_ShuttleTrip> _trips = [
  _ShuttleTrip('07:30', _ShuttleDirection.toLingang),
  _ShuttleTrip('08:00', _ShuttleDirection.toLingang),
  _ShuttleTrip('08:10', _ShuttleDirection.fromLingang),
  _ShuttleTrip('09:20', _ShuttleDirection.toLingang),
  _ShuttleTrip('10:15', _ShuttleDirection.fromLingang),
  _ShuttleTrip('11:00', _ShuttleDirection.toLingang),
  _ShuttleTrip('12:15', _ShuttleDirection.fromLingang),
  _ShuttleTrip('13:30', _ShuttleDirection.toLingang),
  _ShuttleTrip('14:00', _ShuttleDirection.toLingang),
  _ShuttleTrip('16:15', _ShuttleDirection.fromLingang),
  _ShuttleTrip('17:10', _ShuttleDirection.toLingang),
  _ShuttleTrip('18:15', _ShuttleDirection.fromLingang),
  _ShuttleTrip('21:00', _ShuttleDirection.toLingang),
  _ShuttleTrip('21:40', _ShuttleDirection.fromLingang),
];

class ShuttlePage extends StatelessWidget {
  const ShuttlePage({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('校车时间'),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            // 运行说明
            _buildNoteCard(),
            const SizedBox(height: 16),
            // 时刻表
            _buildScheduleCard(),
            const SizedBox(height: 16),
            // 运行路线
            _buildRouteCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteCard() {
    return Card(
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
                color: _yibinOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.info_outline_rounded,
                  color: _yibinOrange, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('运行说明',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    '周末、法定节假日、学校放假停开。\n请提前到达候车点，准时发车。',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600],
                        height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: _yibinBlue.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _yibinBlue,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                const Text('时刻表',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),
            // A区→临港
            _buildDirectionHeader(
                'A区 → 临港校区', Icons.directions_bus_rounded, _yibinBlue),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _trips
                  .where((t) => t.direction == _ShuttleDirection.toLingang)
                  .map((t) => _timeChip(t.time, _yibinBlue))
                  .toList(),
            ),
            const SizedBox(height: 20),
            // 临港→A区
            _buildDirectionHeader(
                '临港校区 → A区', Icons.directions_bus_rounded, _yibinOrange),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _trips
                  .where((t) => t.direction == _ShuttleDirection.fromLingang)
                  .map((t) => _timeChip(t.time, _yibinOrange))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectionHeader(String text, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(text,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  Widget _timeChip(String time, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(time,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color)),
    );
  }

  Widget _buildRouteCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: _yibinBlue.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _yibinBlue,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                const Text('运行路线',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),
            _buildRouteBlock(
              'A区发车 → 临港校区',
              '学院A区（大校门）→ 临港校区（二期办公楼）',
              [
                '酒圣路',
                '学院路',
                '广坪路',
                '观斗山隧道',
                '白塔路',
                '石岗路',
                '大学路',
                '→ 临港校区（二期办公楼）',
              ],
              _yibinBlue,
            ),
            const SizedBox(height: 20),
            _buildRouteBlock(
              '临港校区 → A区',
              '临港校区（二期办公楼）→ 学院A区（大校门）',
              [
                '大学路',
                '石岗路',
                '白塔路',
                '观斗山隧道',
                '川云中路（内环线）',
                '酒圣路',
                '→ 学院A区（大校门）',
              ],
              _yibinOrange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteBlock(
      String title, String startEnd, List<String> roads, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDirectionHeader(title, Icons.alt_route_rounded, color),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(startEnd,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              for (int i = 0; i < roads.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2, bottom: 2),
                    child: Icon(Icons.arrow_downward_rounded,
                        size: 14, color: color.withValues(alpha: 0.5)),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (roads[i].startsWith('→'))
                      Icon(Icons.flag_rounded,
                          size: 14, color: color)
                    else
                      Icon(Icons.circle_rounded,
                          size: 6, color: color.withValues(alpha: 0.5)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        roads[i].startsWith('→') ? roads[i].substring(2) : roads[i],
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
