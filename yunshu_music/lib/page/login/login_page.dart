import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:yunshu_music/provider/login_model.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late GlobalKey<FormState> _formKey;
  late TextEditingController _controller;
  late TextEditingController _signParamController;

  late TextEditingController _signKeyController;

  late TextEditingController _timeParamController;

  late bool _enableSign;

  @override
  void initState() {
    super.initState();
    _formKey = GlobalKey<FormState>();
    final loginModel = LoginModel.get();
    _controller = TextEditingController(text: loginModel.getBaseUrl());
    _signParamController = TextEditingController(
      text: loginModel.getSignParamName(),
    );
    _signKeyController = TextEditingController(text: loginModel.getSignKey());
    _timeParamController = TextEditingController(
      text: loginModel.getAuthorizationTimeParamName(),
    );
    _enableSign = LoginModel.get().getEnableAuthorization();
  }

  @override
  void dispose() {
    _controller.dispose();
    _signParamController.dispose();
    _signKeyController.dispose();
    _timeParamController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            CheckboxListTile(
              title: const Text('启用URL签名'),
              value: _enableSign,
              onChanged: (value) {
                setState(() {
                  _enableSign = value!;
                });
              },
            ),
            if (_enableSign)
              Column(
                children: [
                  TextFormField(
                    controller: _signParamController,
                    decoration: const InputDecoration(
                      labelText: "签名参数名称",
                      hintText: "如 sign",
                      prefixIcon: Icon(Icons.edit),
                    ),
                    validator: (v) {
                      if (v!.trim().isEmpty) {
                        return "签名参数不能为空";
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _signKeyController,
                    decoration: const InputDecoration(
                      labelText: "签名密钥",
                      hintText: "请输入签名密钥",
                      prefixIcon: Icon(Icons.key),
                    ),
                    validator: (v) {
                      if (v!.trim().isEmpty) {
                        return "签名密钥不能为空";
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _timeParamController,
                    decoration: const InputDecoration(
                      labelText: "时间戳参数名",
                      hintText: "请输入时间戳参数名",
                      prefixIcon: Icon(Icons.timer),
                    ),
                    validator: (v) {
                      if (v!.trim().isEmpty) {
                        return "时间戳参数名不能为空";
                      }
                      return null;
                    },
                  ),
                ],
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
      final loginModel = LoginModel.get();

      await loginModel.setBaseUrl(_controller.text.trim());
      await loginModel.setEnableAuthorization(_enableSign);
      await loginModel.setSignParamName(_signParamController.text.trim());
      await loginModel.setSignKey(_signKeyController.text.trim());
      await loginModel.setAuthorizationTimeParamName(_timeParamController.text.trim());

      if (mounted) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          context.go('/');
        }
      }
    }
  }
}
