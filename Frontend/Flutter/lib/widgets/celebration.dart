import 'package:flutter/material.dart';
import 'package:workfire/workfire.dart';
import '../themes/app_colors.dart';
import 'dart:math';

class CelebrationOverlay {
  /// Shows a click-through fireworks overlay with a fading background and text
  static void show(BuildContext context) {
    // Get the current OverlayState
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    // Define the overlay
    overlayEntry = OverlayEntry(
      builder: (context) {
        // Positioned.fill ensures it covers the entire screen
        return Positioned.fill(
          // IgnorePointer makes it click-through, so it doesn't block UI interactions
          child: IgnorePointer(
            child: const _CelebrationAnimationWrapper(),
          ),
        );
      },
    );

    // Insert the firework overlay into the view
    overlayState.insert(overlayEntry);

    // Clean up and remove the overlay completely after the fireworks finish (5 seconds)
    Future.delayed(const Duration(seconds: 5), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }
}

/// A wrapper that handles the 2-second background fade and text pop-in
class _CelebrationAnimationWrapper extends StatefulWidget {
  const _CelebrationAnimationWrapper({Key? key}) : super(key: key);

  @override
  State<_CelebrationAnimationWrapper> createState() => _CelebrationAnimationWrapperState();
}

class _CelebrationAnimationWrapperState extends State<_CelebrationAnimationWrapper> {
  bool _isActive = false;

  @override
  void initState() {
    super.initState();
    // Trigger the fade-in and pop-in right after the widget builds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _isActive = true);
    });

    // Trigger the fade-out and pop-out after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isActive = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Fading 80% Black Background
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          color: Colors.black.withOpacity(_isActive ? 0.8 : 0.0),
        ),
        
        // 2. Popping "WOW Factor" Text
        Center(
          child: AnimatedScale(
            // Increased duration slightly to let the elastic bounce play out
            duration: const Duration(milliseconds: 800),
            curve: _isActive ? Curves.elasticOut : Curves.easeInBack,
            scale: _isActive ? 1.0 : 0.0,
            child: AnimatedRotation(
              duration: const Duration(milliseconds: 800),
              curve: _isActive ? Curves.elasticOut : Curves.easeInBack,
              // Starts tilted back (-0.15 turns) and snaps to straight (0.0)
              turns: _isActive ? 0.0 : -0.15,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _isActive ? 1.0 : 0.0,
                // ShaderMask applies a beautiful gold gradient to the text
                child: ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.amber, Colors.yellowAccent, Colors.orange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: const Text(
                    "NICE JOB!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white, // Required for ShaderMask to work
                      fontSize: 64, // Bigger
                      fontWeight: FontWeight.w900, // Max thickness
                      fontStyle: FontStyle.italic, // Gives it a dynamic, fast feel
                      letterSpacing: 3.0,
                      decoration: TextDecoration.none, // Removes the yellow debug line
                      shadows: [
                        // A tight, dark shadow for 3D depth
                        Shadow(
                          color: Colors.black87,
                          offset: Offset(3, 4),
                          blurRadius: 2,
                        ),
                        // A wide, colorful shadow for a glowing effect
                        Shadow(
                          color: Colors.orangeAccent,
                          offset: Offset(0, 0),
                          blurRadius: 30,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // 3. Your untouched fireworks
        FireworkShow(
          fireworks: List.generate(5, (index) => 
            FireworkConfig(
              curve: Curves.easeIn,
              delay: Duration(milliseconds: 180 + (index * 68)),
              startingPosition: Offset(
                MediaQuery.of(context).size.width / 2,
                MediaQuery.of(context).size.height,
              ),
              endingPosition: Offset(
                (MediaQuery.of(context).size.width / 2) + ((Random().nextDouble() * 100) - 50),
                MediaQuery.of(context).size.height * (0.6 - index * 0.09),
              ),
              particleColors: [
                AppColors.secondary,
                AppColors.accent,
                Colors.orange
              ],
              particleCount: 12 + (index * 2),
              gravity: 80.0,
            ),
          ),
        ),
      ],
    );
  }
}