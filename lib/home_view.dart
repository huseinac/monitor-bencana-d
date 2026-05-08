import 'package:flutter/material.dart';
import 'styles/app_styles.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    // This is your "Blade" template equivalent
    return Scaffold(
      appBar: AppBar(
        title: Row(
            children: [
              Expanded(
                flex: 10,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 42,
                  )
                )
              ),
              Expanded(
                flex: 2,
                child: Container(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/logo2.png',
                          height: 42,
                        ),
                        const SizedBox(width: 14),
                        Image.asset(
                          'assets/images/icon-info.png',
                          height: 20,
                        ),
                        const SizedBox(width: 14),
                        ElevatedButton(
                          style: AppStyles.btnLogin,
                          onPressed: () {
                            // Code to run when clicked
                            print('Button Clicked!');
                          },
                          child: const Text('LOGIN'),
                        )
                      ],
                    )
                  ),
                )
              ),
            ],
          ),
      ),
    );
  }
}