import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:yunshu_music/provider/login_model.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    String? baseUrl = LoginModel.get().getBaseUrl();
    _controller.text = baseUrl ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('设置音乐源')),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          children: [
            TextFormField(
              autofocus: true,
              controller: _controller,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onEditingComplete: setBaseUrl,
              decoration: const InputDecoration(
                labelText: "音乐源",
                hintText: "https://example.com",
                prefixIcon: Icon(Icons.web),
              ),
              validator: (v) {
                if (v!.trim().isEmpty) {
                  return "音乐源不能为空";
                }
                if (!v.trim().startsWith("http://") &&
                    !v.trim().startsWith("https://")) {
                  return "必须http/https协议开头";
                }
                return null;
              },
            ),
            Padding(
              padding: const EdgeInsets.only(
                top: 12.0,
                left: 12.0,
                right: 12.0,
              ),
              child: SizedBox(
                height: 35,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: setBaseUrl,
                  child: const Text('设置'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void setBaseUrl() async {
    if ((_formKey.currentState as FormState).validate()) {
      await LoginModel.get().setBaseUrl(_controller.text.trim());
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        context.go('/');
      }
    }
  }
}
