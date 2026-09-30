/// The two variants an adaptive SVG can be rendered in.
enum SvgColorScheme {
  light,
  dark;

  SvgColorScheme get opposite => this == light ? dark : light;
}
