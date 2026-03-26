import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const String _appUrl = 'https://duozzflow.com';
const String _appDomain = 'duozzflow.com';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF1E293B),
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const DuozzFlowApp());
}

class DuozzFlowApp extends StatelessWidget {
  const DuozzFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Duozz Flow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const WebViewScreen(),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF1F5F9))
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.parse(request.url);
            // Keep duozzflow.com navigation inside the WebView
            if (uri.host == _appDomain || uri.host.endsWith('.$_appDomain')) {
              return NavigationDecision.navigate;
            }
            // Open external links in the system browser
            launchUrl(Uri.parse(request.url), mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          },
          onPageStarted: (url) {
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
          },
          onPageFinished: (url) {
            setState(() => _isLoading = false);
          },
          onProgress: (progress) {
            setState(() => _progress = progress / 100.0);
          },
          onWebResourceError: (error) {
            // Only show error screen for main frame failures
            if (error.isForMainFrame ?? false) {
              setState(() {
                _hasError = true;
                _isLoading = false;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(_appUrl));
  }

  void _reload() {
    setState(() {
      _hasError = false;
      _isLoading = true;
    });
    _controller.loadRequest(Uri.parse(_appUrl));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          await _controller.goBack();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: SafeArea(
          child: Column(
            children: [
              // Progress bar at top
              if (_isLoading)
                LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                  minHeight: 3,
                ),
              Expanded(
                child: _hasError ? _buildErrorView() : WebViewWidget(controller: _controller),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 64, color: Color(0xFF94A3B8)),
            const SizedBox(height: 16),
            const Text(
              'Sem conexao',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Verifique sua internet e tente novamente.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
