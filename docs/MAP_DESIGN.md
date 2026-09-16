# Dasher haritaları

Üç harita aynı yarış kurallarını ve hareket mesafelerini kullanır. Oyuncu -Z
yönünde ilerler; düşüş tur süresini sıfırlamadan başlangıca götürür. Haritadaki
01–08 işaretleri ilerleme göstergesidir; hiçbirisi yeniden doğma noktası değildir.

## İlk sürümün görsel dünyaları

- **Skyline:** Bulutların üstünde, güneşli bir geçiş tesisi. Açık beton
  yüzeyler, yüksek yan duvarlar, geniş cam şeritleri, uzaktaki kuleler ve ince
  turkuaz/gold işaretler. Merkezdeki parkur açık kalır.
- **After Hours / Neon:** Dar bir gece sokağı. Lacivert bina cepheleri,
  aydınlık pencereler, neon panolar, klima üniteleri, tesisat boruları ve asılı
  lambalar. Sokak zemini öldürücüdür; platformların üstü güvenlidir.
- **The Grid:** Dört duvarlı, açık tavanlı klasik kare blok salonu.
  Düzenli duvar panelleri, sade kare platformlar, turkuaz yön çizgileri ve
  altın vurgu blokları. Alt zemin güvenli değildir.

Lobi aynı ana tipografiyi ve turkuaz/gold renk dilini kullanır. Ayrı, güvenli
bir teras üzerinde oturma alanı, kısa kurallar ve küçük Dash alıştırma blokları
bulunur. Lobi alıştırması yarışın bir bölümü değildir.

## Parkur tasarımı

Her haritada başlangıç ve bitiş dâhil 26 ana platform vardır. Sekiz bölümün
her biri üç yüzeyden oluşur. İlk yüzey geniştir; ikinci yüzey daha küçüktür ve
daha uzun boşluk içerir; üçüncü yüzey ilerleme kapısının olduğu güvenli iniştir.
Platformların yürünen üstü y22–24; iki alternatif dar platformun üstü y25'tir.

Dördüncü ve yedinci bölümlerde ana yol yana kıvrılır. Ortadaki dar, altın
işaretli platform bir inişi atlayan daha doğrudan bir rota sunar. Bu rota
ilerleme kapısını atlamaz. Oyuncu hız karşılığında daha hassas inişi seçer.

Boşluklar sırasıyla 3, 14 ve 2 stud'dur. Her bölümdeki 14 stud boşluk,
yukarı yönde 1 stud farkla birlikte yalnız normal sıçramadan daha fazlasını
gerektirir. Dash hedefi 9 stud derinlikte bir iniş yüzeyidir; oyuncu atılmayı
boşluğun tam kenarından önce başlatarak inişini ayarlayabilir. Dar alternatifte iki boşluk yaklaşık
10,5 stud'dur ve ilkinde 1 stud yükseklik farkı vardır. WalkSpeed22,
JumpPower52 ve kısa Dash esas alınmıştır; gerçek zorluk ve süre dengesi
oyuncu testleriyle ayarlanmalıdır. Sayısal ulaşılabilirlik incelemesi,
insanlarla oynanış testi veya mobil kontrol doğrulaması yerine geçmez.

Tüm haritalar yaklaşık 425 stud ilerler. Bitirme hacmi `(0, 29, -425)`;
başlangıç işareti `(0, 26, 5)` konumundadır. Kapılar 16 stud yüksekliğindedir;
havada atılan Dash de ilerleme kontrolünden geçer.

## Üretim ayrıntıları

`tools/world.py` içindeki `build_world()` iki Roblox XML nesnesi döndürür:
`Workspace/Lobby` için bir Model ve `ServerStorage/Maps` için bir Folder.
Çalışma anında yalnız seçilen harita Workspace içine klonlanır.

Her ana platform `Course/<platform adı>/Walkable` yolundadır. Sayısal
rota verileri `COURSE_METADATA[map]['primary']` içindedir; `shortcuts`
listesi alternatif bağlantıların `from_index` / `to_index` değerlerini taşır.
Başlangıç `LaunchDeck`, bitiş `FinishDeck`, diğerleri
`Section01_Pad1`–`Section08_Pad3` biçiminde adlandırılır.

Dekor parçaları sabittir, çarpışma ve dokunma üretmez. Yalnız yürüme yüzeyleri
ile lobi güvenlik duvarları çarpışır. Böylece bina çıkıntıları veya borular
istenmeyen kestirme yüzeylerine dönüşmez. Görsel işaretler ve tüm mimari,
Roblox yerel parçalarından üretilir; dış mesh, doku veya üçüncü taraf model
paketi içermez. Duvarlar yarış dekorudur; merkezdeki yol dışına çıkmak güvenli
bir rota oluşturmaz.

Harita başına parça bütçeleri: Skyline 893, Neon 1.467, Grid 1.091.
Lobi 129 parça içerir. Yalnız aktif harita render edilir; gerçek cihazlarda
performans kontrolü yapılması gerekir. Neon'daki ışıklar gölgesiz ve sınırlı
menzillidir; neon malzeme parlaklığı ayrıca dünya aydınlatmasıyla kontrol edilir.

## Sıradaki tasarım testleri

1. Yeni oyuncu Dash'in ne zaman yenilendiğini ve hangi yüzeylerin güvenli
   olduğunu dışarıdan açıklama almadan anlıyor mu?
2. Aynı bölümü tekrar eden oyuncu inişini iyileştirebiliyor mu?
3. İki dar alternatif, gerçekten zaman kazandırırken makul risk taşıyor mu?
4. Neon sokağında düşük ekran parlaklığında iniş yüzeyleri okunuyor mu?
5. Mobil ekranda avatar, kamera ve efektler hedef yüzeyi kapatıyor mu?

Bu testlerin sonuçları ölçülmeden haritaların zorluklarının eşit olduğu veya
her cihazda sorunsuz çalıştığı iddia edilmemelidir.
