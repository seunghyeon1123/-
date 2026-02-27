class ProductItem {
  final String name;
  final String sku;
  final String category;
  final Set<String> attrs;

  const ProductItem({
    required this.name,
    required this.sku,
    required this.category,
    required this.attrs,
  });
}

const List<String> productCategories = ['전체', '대발', '배접', '2.7/3.6/120', '옻지', '인쇄/나염', '기타'];
const List<String> allProductAttrs = ['순지', '국내', '백닥', '무표백', '황촉규', '無', '색', '옻'];

const List<ProductItem> catalogItems = [
  ProductItem(name: '배접지', sku: 'HJ-BJ-140x80', category: '배접', attrs: {}),
  ProductItem(name: '순지 배접지', sku: 'HJ-BJ-SJ-140x80', category: '배접', attrs: {'순지'}),
  ProductItem(name: '대발지', sku: 'HJ-DB', category: '대발', attrs: {}),
  ProductItem(name: '순지 대발', sku: 'HJ-DB-SJ', category: '대발', attrs: {'순지'}),
  ProductItem(name: '무표백 순지 대발', sku: 'HJ-DB-NB-SJ', category: '대발', attrs: {'무표백', '순지'}),
  ProductItem(name: '국내 순지 대발', sku: 'HJ-DB-KR-SJ', category: '대발', attrs: {'국내', '순지'}),
  ProductItem(name: '무표백 국내 순지 대발', sku: 'HJ-DB-NB-KR-SJ', category: '대발', attrs: {'무표백', '국내', '순지'}),
  ProductItem(name: '무표백 국내 순지 대발 (황촉규)', sku: 'HJ-DB-NB-KR-SJ-HC', category: '대발', attrs: {'무표백', '국내', '순지', '황촉규'}),
  ProductItem(name: '무표백 국내 순지 대발 (無)', sku: 'HJ-DB-NB-KR-SJ-MU', category: '대발', attrs: {'무표백', '국내', '순지', '無'}),
  ProductItem(name: '무표백 국내 순지 대발 (황촉규,無)', sku: 'HJ-DB-NB-KR-SJ-HC-MU', category: '대발', attrs: {'무표백', '국내', '순지', '황촉규', '無'}),
  ProductItem(name: '국내 백닥 대발', sku: 'HJ-DB-KR-BD', category: '대발', attrs: {'국내', '백닥'}),
  ProductItem(name: '국내 백닥 대발 (無)', sku: 'HJ-DB-KR-BD-MU', category: '대발', attrs: {'국내', '백닥', '無'}),
  ProductItem(name: '국내 백닥 대발 (황촉규)', sku: 'HJ-DB-KR-BD-HC', category: '대발', attrs: {'국내', '백닥', '황촉규'}),
  ProductItem(name: '국내 백닥 대발 (황촉규,無)', sku: 'HJ-DB-KR-BD-HC-MU', category: '대발', attrs: {'국내', '백닥', '황촉규', '無'}),
  ProductItem(name: '무표백 국내 백닥 대발 (황촉규)', sku: 'HJ-DB-NB-KR-BD-HC', category: '대발', attrs: {'무표백', '국내', '백닥', '황촉규'}),
  ProductItem(name: '무표백 국내 백닥 대발 (황촉규,無)', sku: 'HJ-DB-NB-KR-BD-HC-MU', category: '대발', attrs: {'무표백', '국내', '백닥', '황촉규', '無'}),
  ProductItem(name: '무표백 순지 대발 (無)', sku: 'HJ-DB-NB-SJ-MU', category: '대발', attrs: {'무표백', '순지', '無'}),
  ProductItem(name: '무표백 순지 대발 (색)', sku: 'HJ-DB-NB-SJ-CL', category: '대발', attrs: {'무표백', '순지', '색'}),
  ProductItem(name: '무표백 순지 대발 (황촉규)', sku: 'HJ-DB-NB-SJ-HC', category: '대발', attrs: {'무표백', '순지', '황촉규'}),
  ProductItem(name: '호두지', sku: 'HJ-HDJ', category: '기타', attrs: {}),
  ProductItem(name: '백닥 소발(박)', sku: 'HJ-SB-BD-PK', category: '대발', attrs: {'백닥'}),
  ProductItem(name: '외발지', sku: 'HJ-WB', category: '기타', attrs: {}),
  ProductItem(name: '2.7지', sku: 'HJ-27', category: '2.7/3.6/120', attrs: {}),
  ProductItem(name: '순지 2.7지', sku: 'HJ-27-SJ', category: '2.7/3.6/120', attrs: {'순지'}),
  ProductItem(name: '국내 2.7지', sku: 'HJ-27-KR', category: '2.7/3.6/120', attrs: {'국내'}),
  ProductItem(name: '백닥 2.7지', sku: 'HJ-27-BD', category: '2.7/3.6/120', attrs: {'백닥'}),
  ProductItem(name: '무표백 3.6지', sku: 'HJ-36-NB', category: '2.7/3.6/120', attrs: {'무표백'}),
  ProductItem(name: '무표백 국내 3.6지', sku: 'HJ-36-NB-KR', category: '2.7/3.6/120', attrs: {'무표백', '국내'}),
  ProductItem(name: '백닥 3.6지', sku: 'HJ-36-BD', category: '2.7/3.6/120', attrs: {'백닥'}),
  ProductItem(name: '120호', sku: 'HJ-120', category: '2.7/3.6/120', attrs: {}),
  ProductItem(name: '120호 (황촉규)', sku: 'HJ-120-HC', category: '2.7/3.6/120', attrs: {'황촉규'}),
  ProductItem(name: '3.6 옻지', sku: 'HJ-36-OT', category: '옻지', attrs: {'옻'}),
  ProductItem(name: '2.7 옻지', sku: 'HJ-27-OT', category: '옻지', attrs: {'옻'}),
  ProductItem(name: '120호 옻지', sku: 'HJ-120-OT', category: '옻지', attrs: {'옻'}),
  ProductItem(name: '창호지', sku: 'HJ-CH', category: '기타', attrs: {}),
  ProductItem(name: '중지', sku: 'HJ-JZ', category: '기타', attrs: {}),
  ProductItem(name: '순지', sku: 'HJ-SJ', category: '기타', attrs: {'순지'}),
  ProductItem(name: '지방지', sku: 'HJ-JB', category: '기타', attrs: {}),
  ProductItem(name: '색한지', sku: 'HJ-CLHJ', category: '기타', attrs: {'색'}),
  ProductItem(name: '피지 1합', sku: 'HJ-PI-1H', category: '기타', attrs: {}),
  ProductItem(name: '피지 2합', sku: 'HJ-PI-2H', category: '기타', attrs: {}),
  ProductItem(name: '낙수지', sku: 'HJ-LSJ', category: '기타', attrs: {}),
  ProductItem(name: '꽃나염지', sku: 'HJ-FPR', category: '인쇄/나염', attrs: {}),
  ProductItem(name: '나염지', sku: 'HJ-PR', category: '인쇄/나염', attrs: {}),
  ProductItem(name: '글지', sku: 'HJ-GJ', category: '인쇄/나염', attrs: {}),
  ProductItem(name: '색인쇄지', sku: 'HJ-CPR', category: '인쇄/나염', attrs: {}),
  ProductItem(name: '실크 스크린지', sku: 'HJ-SS', category: '인쇄/나염', attrs: {}),
  ProductItem(name: '옻지 40*60', sku: 'HJ-OT-40x60', category: '옻지', attrs: {'옻'}),
  ProductItem(name: '옻지 50*70', sku: 'HJ-OT-50x70', category: '옻지', attrs: {'옻'}),
];