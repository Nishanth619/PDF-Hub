import 'package:flutter/material.dart';

/// Screen size breakpoints for responsive design
class ScreenBreakpoints {
  static const double smallPhone = 360;  // Small phones
  static const double normalPhone = 400; // Normal phones
  static const double largePhone = 600;  // Large phones / phablets
  static const double tablet = 900;      // Tablets
  static const double desktop = 1200;    // Desktop / large tablets
}

/// Device type based on screen width
enum DeviceType {
  smallPhone,
  phone,
  largePhone,
  tablet,
  desktop,
}

/// Responsive utilities for adaptive layouts
class ResponsiveUtils {
  /// Get device type based on screen width
  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    
    if (width < ScreenBreakpoints.smallPhone) {
      return DeviceType.smallPhone;
    } else if (width < ScreenBreakpoints.largePhone) {
      return DeviceType.phone;
    } else if (width < ScreenBreakpoints.tablet) {
      return DeviceType.largePhone;
    } else if (width < ScreenBreakpoints.desktop) {
      return DeviceType.tablet;
    } else {
      return DeviceType.desktop;
    }
  }
  
  /// Check if device is a tablet or larger
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= ScreenBreakpoints.tablet;
  }
  
  /// Check if device is a large phone or larger
  static bool isLargeDevice(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= ScreenBreakpoints.largePhone;
  }
  
  /// Get number of grid columns based on screen width
  static int getGridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    
    if (width < ScreenBreakpoints.smallPhone) {
      return 2; // Small phones: 2 columns
    } else if (width < ScreenBreakpoints.largePhone) {
      return 2; // Normal phones: 2 columns
    } else if (width < ScreenBreakpoints.tablet) {
      return 3; // Large phones: 3 columns
    } else if (width < ScreenBreakpoints.desktop) {
      return 4; // Tablets: 4 columns
    } else {
      return 5; // Desktop: 5 columns
    }
  }
  
  /// Get card aspect ratio based on screen size
  static double getCardAspectRatio(BuildContext context) {
    final deviceType = getDeviceType(context);
    
    switch (deviceType) {
      case DeviceType.smallPhone:
        return 0.95; // Slightly taller cards on small phones
      case DeviceType.phone:
        return 1.0;  // Square cards on phones
      case DeviceType.largePhone:
        return 1.05; // Slightly wider on large phones
      case DeviceType.tablet:
        return 1.1;  // Wider cards on tablets
      case DeviceType.desktop:
        return 1.15; // Widest on desktop
    }
  }
  
  /// Get horizontal padding based on screen size
  static double getHorizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    
    if (width < ScreenBreakpoints.largePhone) {
      return 16.0;
    } else if (width < ScreenBreakpoints.tablet) {
      return 24.0;
    } else {
      return 32.0;
    }
  }
  
  /// Get content scale factor for tablets (1.0 = phone, 1.3 = tablet)
  static double getContentScale(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    
    if (width < ScreenBreakpoints.largePhone) {
      return 1.0;  // Phone - normal scale
    } else if (width < ScreenBreakpoints.tablet) {
      return 1.15; // Large phone - slightly larger
    } else if (width < ScreenBreakpoints.desktop) {
      return 1.3;  // Tablet - 30% larger
    } else {
      return 1.4;  // Desktop - 40% larger
    }
  }
  
  /// Scale a value based on device type
  static double scale(BuildContext context, double value) {
    return value * getContentScale(context);
  }
  
  /// Get scaled font size
  static double fontSize(BuildContext context, double baseSize) {
    return baseSize * getContentScale(context);
  }
  
  /// Get scaled icon size
  static double iconSize(BuildContext context, double baseSize) {
    return baseSize * getContentScale(context);
  }
  
  /// Get scaled padding
  static double padding(BuildContext context, double basePadding) {
    return basePadding * getContentScale(context);
  }
  
  /// Get scaled spacing
  static double spacing(BuildContext context, double baseSpacing) {
    return baseSpacing * getContentScale(context);
  }
  
  /// Get grid spacing based on screen size
  static double getGridSpacing(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    
    if (width < ScreenBreakpoints.smallPhone) {
      return 10.0;
    } else if (width < ScreenBreakpoints.largePhone) {
      return 14.0;
    } else if (width < ScreenBreakpoints.tablet) {
      return 18.0;
    } else {
      return 24.0;
    }
  }
  
  /// Get button height scaled for device
  static double buttonHeight(BuildContext context) {
    return scale(context, 48);
  }
  
  /// Get app bar height scaled for device
  static double appBarHeight(BuildContext context) {
    return isTablet(context) ? kToolbarHeight * 1.2 : kToolbarHeight;
  }
}

/// Extension for responsive sizing directly on numbers
extension ResponsiveNum on num {
  /// Scale value based on screen size
  double scaledWith(BuildContext context) {
    return toDouble() * ResponsiveUtils.getContentScale(context);
  }
}
