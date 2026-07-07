import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

const Color _yibinBlue = Color.fromRGBO(25, 25, 153, 1);
const Color _redAccent = Color.fromRGBO(211, 47, 47, 1);
const Color _amber = Color.fromRGBO(255, 160, 0, 1);

class SafetyPage extends StatelessWidget {
  const SafetyPage({super.key});

  static const _tips = [
    '严守出入规范，主动配合校门安保核验，不擅自留宿校外人员，筑牢校园安全第一道防线。',
    '注意宿舍安全，不使用违规电器、不私拉乱接电线，离开时关好门窗、切断电源，防范火灾与盗窃风险。',
    '规范交通出行，在校园内骑行减速慢行，不逆行、不违规载人，有序停放车辆，避让行人。',
    '警惕各类诈骗，不轻信陌生来电、中奖信息，不随意透露个人信息，转账汇款务必核实，守护财产安全。',
    '注重活动安全，参与体育锻炼、实验实训等活动时，遵守操作规范与场地要求，做好防护措施。',
    '关爱身心健康，遇到矛盾纠纷冷静沟通，主动向辅导员、学校心理育人中心求助，远离校园欺凌。',
  ];

  static const _phones = [
    ('临港校区', '0831-3578110'),
    ('江北校区（A区/B区）', '0831-3548110'),
  ];

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('校园安全'),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            _buildEmergencyCard(),
            const SizedBox(height: 16),
            _buildPhonesCard(),
            const SizedBox(height: 16),
            _buildTipsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: _redAccent.withValues(alpha: 0.15)),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [
              _redAccent.withValues(alpha: 0.06),
              _redAccent.withValues(alpha: 0.02),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.emergency_rounded, size: 40, color: _redAccent),
              const SizedBox(height: 8),
              const Text('紧急求助电话',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _redAccent)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _emergencyBtn('110', '报警', Icons.local_police_rounded),
                  _emergencyBtn('119', '火警', Icons.fire_extinguisher_rounded),
                  _emergencyBtn('120', '急救', Icons.healing_rounded),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emergencyBtn(String number, String label, IconData icon) {
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse('tel:$number'),
          mode: LaunchMode.externalApplication),
      child: Container(
        width: 88,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _redAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 26, color: _redAccent),
            const SizedBox(height: 6),
            Text(number,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _redAccent)),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: _redAccent.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }

  Widget _buildPhonesCard() {
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
                const Text('校内 24 小时值班电话',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),
            for (final (campus, phone) in _phones) ...[
              _phoneRow(campus, phone),
              if (campus != _phones.last.$1) const SizedBox(height: 12),
            ],
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _yibinBlue.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('校园24小时值班，安全守护时刻在线',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500])),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _phoneRow(String campus, String phone) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _yibinBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.phone_rounded,
              size: 18, color: _yibinBlue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(campus,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(phone,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _yibinBlue)),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => launchUrl(Uri.parse('tel:$phone'),
              mode: LaunchMode.externalApplication),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _yibinBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('拨打',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildTipsCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: _amber.withValues(alpha: 0.15)),
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
                    color: _amber,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                const Text('安全提醒',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),
            for (int i = 0; i < _tips.length; i++) ...[
              _tipItem(i + 1, _tips[i]),
              if (i < _tips.length - 1) const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tipItem(int index, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: _amber.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text('$index',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _amber)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey[700], height: 1.5)),
        ),
      ],
    );
  }
}
