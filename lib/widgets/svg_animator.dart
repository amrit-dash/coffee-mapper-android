import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:coffee_mapper/utils/logger.dart';

class LoaderBeanWidget extends StatefulWidget {
  final Color color1;
  final Color color2;
  final double size;

  const LoaderBeanWidget({
    super.key,
    required this.color1,
    required this.color2,
    this.size = 100.0,
  });

  @override
  LoaderBeanWidgetState createState() => LoaderBeanWidgetState();
}

class LoaderBeanWidgetState extends State<LoaderBeanWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade1;
  late Animation<double> _fade2;
  String? _svgString;
  final _logger = AppLogger.getLogger('LoaderBeanWidget');

  @override
  void initState() {
    super.initState();
    _loadSvg();

    _controller = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat();

    _fade1 = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 1),
    ]).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5)),
    );

    _fade2 = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 1),
    ]).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.5, 1.0)),
    );
  }

  Future<void> _loadSvg() async {
    try {
      final svgString = await rootBundle.loadString('assets/logo/loaderBean.svg');
      if (!mounted) return;
      setState(() {
        _svgString = svgString;
      });
    } catch (e) {
      _logger.warning('Failed to load SVG: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_svgString == null) {
      // Show a loading indicator while the SVG is being loaded
      return const Center(child: CircularProgressIndicator());
    }

    return SizedBox(
      height: widget.size,
      width: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            children: [
              Opacity(
                opacity: _fade1.value,
                child: SvgPicture.string(
                  _svgString!,
                  colorFilter: ColorFilter.mode(widget.color1, BlendMode.srcIn),
                ),
              ),
              Opacity(
                opacity: _fade2.value,
                child: SvgPicture.string(
                  _svgString!,
                  colorFilter: ColorFilter.mode(widget.color2, BlendMode.srcIn),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
