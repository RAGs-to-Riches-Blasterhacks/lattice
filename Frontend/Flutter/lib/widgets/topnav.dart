import 'package:flutter/material.dart';

// Note: Make sure to import your AppColors file here.
import '../themes/app_colors.dart';


import 'package:flutter_svg/flutter_svg.dart';

class TopNav extends StatelessWidget implements PreferredSizeWidget {
  const TopNav({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.background, 
      elevation: 0, // Removes the drop shadow for a flatter, modern look
      iconTheme: const IconThemeData(
        color: AppColors.secondary, // Applies white to the leading/action icons
      ),
      centerTitle: true,
      
      // Left: Hamburger Menu
      leading: IconButton(
        icon: const Icon(Icons.menu),
        iconSize: MediaQuery.sizeOf(context).width * 0.09,
        onPressed: () => Scaffold.of(context).openDrawer(),
      ),
      
      // Middle: Logo
      title: Image.asset('assets/LOGO.png',
      width: MediaQuery.sizeOf(context).width * 0.36, 
        
        // Ensures the image shrinks to fit the width without stretching
        fit: BoxFit.contain, 
      ),
      
      
      // Right: Profile Icon
      actions: [
        IconButton(
          icon: SvgPicture.asset(
            'assets/Profile.svg', // Your actual file path

            // This colorFilter safely applies your AppColors.secondary (white) 
            // to the SVG, just in case the original SVG is black or another color.
            colorFilter: const ColorFilter.mode(
              AppColors.secondary, 
              BlendMode.srcIn,
            ),
          ),
          onPressed: () {
            Navigator.pushNamed(context, '/profile');
          },
        ),
        // Adding a little padding to the right so it doesn't hug the screen edge
        const SizedBox(width: 8), 
      ],
    );
  }

  // Required for implementing PreferredSizeWidget
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}