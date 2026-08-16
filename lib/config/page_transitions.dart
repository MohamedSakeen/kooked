import 'package:flutter/material.dart';

class SlideFadeRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SlideFadeRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final fadeTween = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            );
            final slideTween =
                Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero)
                    .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );

            return FadeTransition(
              opacity: fadeTween,
              child: SlideTransition(
                position: slideTween,
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        );
}

class FadeRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  FadeRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 250),
        );
}

Widget slideFadeTransition(
    BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
  final fadeTween = Tween<double>(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(parent: animation, curve: Curves.easeOut),
  );
  final slideTween =
      Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(
    CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
  );

  return FadeTransition(
    opacity: fadeTween,
    child: SlideTransition(
      position: slideTween,
      child: child,
    ),
  );
}
