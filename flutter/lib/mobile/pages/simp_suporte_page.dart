// SIMP View 18/11 (mock aprovado pelo Plinio): tela única para o cliente no Android.
// Um botão "Iniciar suporte" -> pergunta do Android (só tela inteira) -> se faltar,
// cartão "Falta 1 passo" para ligar o controle na Acessibilidade -> ID e senha grandes.
// Sem aviso de golpe, sem pedir notificação / sobrepor apps / acesso a arquivos.
// As opções técnicas antigas ficam em "Opções avançadas" (menu ⋮).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../common.dart';
import '../../consts.dart';
import '../../models/platform_model.dart';
import '../../models/server_model.dart';

const _verde = Color(0xFF43A047);
const _verdeEsc = Color(0xFF2E7D32);
const _verdeClaro = Color(0xFFE8F5E9);
const _vermelho = Color(0xFFE53935);
const _cinza = Color(0xFF6B6F74);

class SimpSuportePage extends StatefulWidget {
  final VoidCallback onChat;
  const SimpSuportePage({Key? key, required this.onChat}) : super(key: key);

  @override
  State<SimpSuportePage> createState() => _SimpSuportePageState();
}

class _SimpSuportePageState extends State<SimpSuportePage>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _pulouControle = false;
  bool _mostraRestrita = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = periodic_immediate(const Duration(seconds: 3), () async {
      await gFFI.serverModel.fetchID();
    });
    gFFI.serverModel.checkAndroidPermission();
    gFFI.invokeMethod("check_service");
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  // voltou da configuração do Android: confere se o controle ficou ligado
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      gFFI.invokeMethod("check_service");
    }
  }

  Future<void> _iniciar(ServerModel m) async {
    if (!m.isStart) {
      await m.startService();
    } else if (!m.mediaOk) {
      await gFFI.invokeMethod("init_service");
    }
  }

  Future<void> _encerrar(ServerModel m) async {
    if (m.isStart) await m.stopService();
    setState(() => _pulouControle = false);
  }

  void _copiar(String t) {
    Clipboard.setData(ClipboardData(text: t));
    showToast('Copiado');
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: gFFI.serverModel,
      child: Consumer<ServerModel>(builder: (context, m, _) {
        final ativo = m.isStart && m.mediaOk;
        final conectados =
            m.clients.where((c) => c.authorized && !c.disconnected).toList();
        final List<Widget> filhos;
        if (!ativo) {
          filhos = _inicio(m);
        } else if (!m.inputOk && !_pulouControle) {
          filhos = _faltaControle(m);
        } else if (conectados.isNotEmpty) {
          filhos = _emAtendimento(m, conectados.first);
        } else {
          filhos = _pronto(m);
        }
        return Container(
          color: const Color(0xFFF2F2F2),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
              children: filhos,
            ),
          ),
        );
      }),
    );
  }

  Widget _card(List<Widget> c, {EdgeInsets? padding}) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x14000000), blurRadius: 2, offset: Offset(0, 1))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: c),
      );

  Widget _botao(String t, VoidCallback? f,
          {Color cor = _verde, Color texto = Colors.white, double alt = 54, double fonte = 17}) =>
      SizedBox(
        height: alt,
        child: ElevatedButton(
          onPressed: f,
          style: ElevatedButton.styleFrom(
            backgroundColor: cor,
            foregroundColor: texto,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(t, style: TextStyle(fontSize: fonte, fontWeight: FontWeight.w600)),
        ),
      );

  Widget _passo(int n, String antes, String chip, [String depois = '']) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: _verdeClaro, shape: BoxShape.circle),
            child: Text('$n',
                style: const TextStyle(fontSize: 12, color: _verdeEsc, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(TextSpan(style: const TextStyle(fontSize: 14.5, color: Colors.black87), children: [
              TextSpan(text: antes),
              TextSpan(text: chip, style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: depois),
            ])),
          ),
        ]),
      );

  List<Widget> _inicio(ServerModel m) {
    final esperando = m.isStart && !m.mediaOk;
    return [
      _card([
        Center(child: SizedBox(height: 60, child: loadLogo())),
        const SizedBox(height: 8),
        const Text('Suporte remoto',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const Text('da Simplificação',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: _cinza)),
      ], padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16)),
      _card([
        Text(
          esperando
              ? 'Toque em "Iniciar" na pergunta do celular para o técnico ver sua tela.'
              : 'Toque abaixo quando o técnico pedir. Ele só vê sua tela depois disso, e você pode encerrar a qualquer momento.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14.5, color: Colors.black87),
        ),
        const SizedBox(height: 14),
        _botao(esperando ? 'Tentar de novo' : 'Iniciar suporte', () => _iniciar(m), alt: 62, fonte: 19),
      ]),
    ];
  }

  List<Widget> _faltaControle(ServerModel m) => [
        _card([
          const Text('Falta 1 passo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Para o técnico poder tocar na sua tela:',
              style: TextStyle(fontSize: 14, color: _cinza)),
          const SizedBox(height: 6),
          _passo(1, 'Toque em ', 'Abrir configuração'),
          _passo(2, 'Toque em ', 'Aplicativos instalados', ' (ou Serviços instalados)'),
          _passo(3, 'Toque em ', 'SIMP View - controle remoto'),
          _passo(4, 'Ligue a chave e toque em ', 'Permitir'),
          const SizedBox(height: 12),
          _botao('Abrir configuração',
              () => AndroidPermissionManager.startAction(kActionAccessibilitySettings)),
          TextButton(
            onPressed: () => setState(() => _pulouControle = true),
            child: const Text('Agora não (o técnico só vê a tela)',
                style: TextStyle(color: _verdeEsc, fontWeight: FontWeight.w600)),
          ),
        ]),
        _card([
          InkWell(
            onTap: () => setState(() => _mostraRestrita = !_mostraRestrita),
            child: Row(children: [
              const Expanded(
                child: Text('A chave está cinza ou apareceu "Configuração restrita"?',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
              ),
              Icon(_mostraRestrita ? Icons.expand_less : Icons.expand_more, color: _cinza),
            ]),
          ),
          if (_mostraRestrita) ...[
            const SizedBox(height: 6),
            _passo(1, 'Toque em ', 'Abrir informações do app'),
            _passo(2, 'Toque nos ', '⋮', ' no canto de cima'),
            _passo(3, 'Toque em ', 'Permitir configurações restritas'),
            _passo(4, 'Volte aqui e toque em ', 'Abrir configuração'),
            const SizedBox(height: 10),
            _botao('Abrir informações do app',
                () => AndroidPermissionManager.startAction(kActionApplicationDetailsSettings),
                cor: _verdeClaro, texto: _verdeEsc, alt: 46, fonte: 15),
          ],
        ]),
        _botao('Encerrar suporte', () => _encerrar(m), cor: _vermelho, alt: 50, fonte: 16),
      ];

  List<Widget> _pronto(ServerModel m) {
    final id = m.serverId.value.text.trim();
    final senha = m.serverPasswd.value.text.trim();
    final idLimpo = id.replaceAll(' ', '');
    return [
      _card([
        const Text('Passe para o técnico', style: TextStyle(fontSize: 13, color: _cinza)),
        const SizedBox(height: 10),
        const Text('ID', style: TextStyle(fontSize: 13, color: _cinza)),
        SelectableText(id, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 8),
        const Text('Senha', style: TextStyle(fontSize: 13, color: _cinza)),
        Row(children: [
          Expanded(
            child: SelectableText(senha,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
          ),
          IconButton(
            tooltip: 'Nova senha',
            icon: const Icon(Icons.refresh, color: _cinza),
            onPressed: () => bind.mainUpdateTemporaryPassword(),
          ),
        ]),
        const SizedBox(height: 12),
        _botao('Copiar ID e senha', () => _copiar('SIMP View\nID: $idLimpo\nSenha: $senha'),
            cor: _verdeClaro, texto: _verdeEsc, alt: 46, fonte: 15),
        const SizedBox(height: 12),
        Row(children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(color: _verde, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          const Text('Aguardando o técnico',
              style: TextStyle(fontSize: 14, color: _verdeEsc, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 4),
        Text('Tela ✓ · Controle ${m.inputOk ? "✓" : "desligado"}',
            style: const TextStyle(fontSize: 13, color: _cinza)),
        if (!m.inputOk)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _pulouControle = false),
              child: const Text('Liberar o controle',
                  style: TextStyle(color: _verdeEsc, fontWeight: FontWeight.w600)),
            ),
          ),
      ]),
      _botao('Encerrar suporte', () => _encerrar(m), cor: _vermelho, alt: 50, fonte: 16),
    ];
  }

  List<Widget> _emAtendimento(ServerModel m, Client c) {
    final nome = c.name.isNotEmpty ? c.name : c.peerId;
    final inicial = nome.isNotEmpty ? nome[0].toUpperCase() : '?';
    return [
      _card([
        Center(
          child: CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFF8E1B4D),
            child: Text(inicial, style: const TextStyle(fontSize: 26, color: Colors.white)),
          ),
        ),
        const SizedBox(height: 10),
        Text('$nome está vendo sua tela',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
        Text(m.inputOk ? 'e pode tocar nela para te ajudar' : 'o controle está desligado: ele só vê',
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: _cinza)),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
              width: 10, height: 10, decoration: const BoxDecoration(color: _verde, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          const Text('Em atendimento',
              style: TextStyle(fontSize: 14, color: _verdeEsc, fontWeight: FontWeight.w600)),
        ]),
      ], padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16)),
      _botao('Chat com o técnico', widget.onChat, cor: Colors.white, texto: _verdeEsc, alt: 48, fonte: 15),
      const SizedBox(height: 12),
      _botao('Encerrar suporte', () => _encerrar(m), cor: _vermelho, alt: 50, fonte: 16),
    ];
  }
}
