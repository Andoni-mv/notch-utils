# NotchUtils

App agente de macOS que muestra lo que suena en **Spotify** al pasar el ratón por el **notch** del MacBook.

## Demo

[Ver demo](asset/demo.gif)

- Sin icono en el Dock (app agente, `LSUIElement`).
- Lee Spotify por **AppleScript** (sin API key, sin red salvo la carátula).
- Refresco en vivo vía la notificación `com.spotify.client.PlaybackStateChanged`.
- Uso personal: firma ad-hoc local, sin notarizar.

## Requisitos

- macOS 14+ (probado en macOS 26).
- Xcode / Command Line Tools (usa `swiftc`, no necesita abrir Xcode).
- Spotify (app de escritorio) instalada.

## Compilar

```bash
./build.sh
```

Genera `build/NotchUtils.app` (compila con `swiftc` y firma ad-hoc con los entitlements).

## Ejecutar

```bash
open build/NotchUtils.app
# o, para ver logs en consola:
build/NotchUtils.app/Contents/MacOS/NotchUtils
```

Al arrancar no aparece nada visible: pasa el ratón por el notch y se despliega el panel.

## Permisos (primera ejecución)

1. **Automatización**: macOS pedirá permiso para que NotchUtils controle Spotify
   (Ajustes → Privacidad y seguridad → Automatización). Acéptalo o no habrá datos.
2. No necesita Accesibilidad ni Grabación de pantalla.

## Estructura

```
Sources/
  main.swift               # arranque de la app agente (.accessory)
  NotchController.swift     # orquesta geometría, hover, panel y Spotify
  NotchGeometry.swift       # rect del notch (con fallback sin notch)
  HoverMonitor.swift        # monitor global/local de mouseMoved
  NotchPanel.swift          # NSPanel borderless sobre el notch
  SpotifyController.swift    # AppleScript + carátula + notificación
  NowPlaying.swift          # modelo + store observable
  NowPlayingView.swift      # UI SwiftUI del panel
Resources/
  Info.plist                # LSUIElement, NSAppleEventsUsageDescription
  NotchUtils.entitlements    # automation.apple-events, sandbox off
build.sh                    # compila + arma bundle + firma ad-hoc
```

## Instalar y arrancar al iniciar sesión

```bash
./install.sh              # compila + copia a /Applications + registra inicio + lanza
./install.sh --no-build   # igual, sin recompilar
```

El script instala en `/Applications`, registra la app como elemento de inicio
(idempotente, no duplica) y la relanza. Para quitarla del inicio: Ajustes del
Sistema → General → Elementos de inicio → selecciona NotchUtils → **−**.

## Controles

El panel incluye controles básicos: **anterior**, **play/pausa**, **siguiente**
(columna derecha, con hover y cursor de mano). Clic directo sobre el panel
(sin activar la app).

Debajo hay una **barra de progreso** con tiempo transcurrido / total, que
avanza en vivo mientras el panel está visible (sondeo cada 1 s). Es
**arrastrable**: clic o arrastre para saltar a otra posición (scrubbing).

A la derecha hay una **columna de volumen vertical** (con icono de altavoz
debajo) que ajusta el volumen de Spotify (0–100): clic o arrastre.

Al hacer **clic en la carátula** se abre / trae al frente Spotify (muestra un
realce y el cursor de mano al pasar por encima).

El **fondo se tinta** con el color dominante de la carátula (media de color
realzada), con transición suave al cambiar de canción.

Al aparecer/desaparecer, el panel **se expande desde el notch** (y colapsa de
vuelta) con una animación de muelle: el fondo escala desde el tamaño físico real
del notch (anclado arriba-centro) y el contenido se funde con un ligero desenfoque.

## Notas / futuras mejoras

- Shuffle/repeat, letras sincronizadas o multi-fuente (Apple Music / MediaRemote).
- Para soportar Apple Music o navegador se podría añadir MediaRemote como fuente
  alternativa (API privada, no apta App Store).
```
