# Dasher — ilk sürüm tasarımı

## Kabul edilen yön

- Üç harita sırayla oynanır: bulutlar üzerinde açık hava ve yan duvarlar, neon gece sokağı, dört duvar içinde klasik blok parkuru.
- Her düşüş parkurun başına gönderir. Ara kayıt noktası yoktur. Görünmez geçiş kapıları yalnız sunucunun gerçek ilerlemeyi denetlemesi içindir.
- Oyuncular kendi Roblox avatarlarını kullanır. Dash herkeste bulunur; para güç satın almaz.
- Modern, koyu arayüz; açık metin, turkuaz hareket vurgusu, altın coin sembolü. Harita rengi arayüzün küçük vurgu alanlarında değişir.
- Zorluk öğrenilebilir mesafeler ve hassas zamanlamadan gelir; belirsiz çarpışmalardan ve görünmeyen tehlikelerden gelmez.

## Yarış kuralları

1. Lobi ve kısa tur arası.
2. Yeni haritaya geçiş, başlangıç geri sayımı.
3. Dört dakika boyunca yarış. Düşüşte en başa dönüş; kişisel süre sıfırlanmaz.
4. İlk bitirenin tek seferlik hızlandırma hakkı. Ortak tur saati 1,5 kat hızlanır; kişisel bitirme süresi gerçek zamanı ölçer.
5. Tur süresi dolunca veya aktif yarışmacılar bitirince sonuçlar, ardından sıradaki harita.
6. Sonradan katılan oyuncu devam eden yarışa baştan girer; kişisel başlangıç zamanı kendisine aittir.

## İlk sürüm dışındaki fikirler

Grapple, Rewind, Wall-run, Robux ürünleri, haftalık küresel sıralama, rastgele harita üretimi ve özel müzik paketi bu sürüme dahil değildir. Hareket ve yarış döngüsü doğrulanmadan bunlar eklenmez.

## Oyuncu testinde toplanacak bilgiler

- Oyuncu açıklama almadan Dash'i ve hedefi anlıyor mu?
- İlk hata nerede, sonraki denemelerde gelişim var mı?
- Kamera/efektler iniş noktasını gizliyor mu?
- Oyuncu kendiliğinden tekrar denemek istiyor mu?
- Süre hızlandırma rekabeti artırıyor mu, yoksa sürekli yarıda kalma hissi mi yaratıyor?
- Mobil oyuncu hareket + zıplama + Dash'i rahat kullanabiliyor mu?

## Geliştirme günlüğü şablonu

Tarih / harita / gözlem / hipotez / yapılan değişiklik / tekrar test sonucu.
Sayısal sonuç yalnız gerçekten ölçüldüğünde yazılır. Kabul komitesine sunulacak anlatı, kod miktarından çok tasarım kararlarının gerekçesine odaklanır.
