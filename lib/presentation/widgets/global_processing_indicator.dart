import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';

import '../../features/processing/bloc/processor_bloc.dart';

class GlobalProcessingIndicator extends StatefulWidget {
  const GlobalProcessingIndicator({super.key});

  @override
  State<GlobalProcessingIndicator> createState() =>
      _GlobalProcessingIndicatorState();
}

class _GlobalProcessingIndicatorState extends State<GlobalProcessingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
    AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _statusColor(ProcessorStatus status) {
    switch (status) {
      case ProcessorStatus.ongoing:
        return Colors.amber;
      case ProcessorStatus.success:
        return Colors.green;
      case ProcessorStatus.failure:
        return Colors.red;
      default:
        return (kDebugMode) ? Colors.grey : Colors.transparent;
    }
  }

  IconData _statusIcon(ProcessorStatus status) {
    switch (status) {
      case ProcessorStatus.ongoing:
        return Icons.sync;
      case ProcessorStatus.success:
        return Icons.check_circle;
      case ProcessorStatus.failure:
        return Icons.error;
      default:
        return Icons.circle;
    }
  }
  String _getTextFromStatus(ProcessorStatus status) {
    switch (status) {
      case ProcessorStatus.ongoing:
        return "Processing Video";
      case ProcessorStatus.success:
        return "Processing Successful";
      case ProcessorStatus.failure:
        return "Processing Failed";
      default:
        return "Idle";
    }
  }



  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProcessorBloc, ProcessorState>(
      buildWhen: (p, c) =>
      p.status != c.status || p.progress != c.progress,
      builder: (context, state) {
        if ((!kDebugMode) && state.status == ProcessorStatus.idle) {
          return const SizedBox.shrink();
        }

        final color = _statusColor(state.status);

        return AnimatedScale(
          scale: state.status == ProcessorStatus.ongoing ? 1 : 1.05,
          duration: const Duration(milliseconds: 300),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: (state.status == ProcessorStatus.idle) ? color.withOpacity(0.5) : Colors.grey.withOpacity(0.5),//
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (_, child) {
                    return Transform.rotate(
                      angle: state.status == ProcessorStatus.ongoing
                          ? _controller.value * 2 * pi
                          : 0,
                      child: child,
                    );
                  },
                  child: Icon(
                    _statusIcon(state.status),
                    size: 18,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getTextFromStatus(state.status),
                      // state.status.name.capitalizeFirst??"Idle",
                      // state.status == ProcessorStatus.ongoing
                      //     ? 'Processing'
                      //     : state.status == ProcessorStatus.success
                      //     ? 'Completed'
                      //     : 'Failed',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    if (state.status == ProcessorStatus.ongoing)
                      SizedBox(
                        width: 80,
                        child: LinearProgressIndicator(
                          value: state.progress.clamp(0, 1),
                          minHeight: 4,
                          backgroundColor: color.withOpacity(0.25),
                          valueColor:
                          AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    if (state.status == ProcessorStatus.ongoing)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '${(state.progress * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 10,
                            color: color,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}