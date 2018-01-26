# Guía para usar la línea de comandos de Bootic (Bootic CLI)

El CLI de Bootic es una herramienta para diseñadores y desarrolladores que
realizar tareas con la API de Bootic en forma local, ya sea ver o modificar
datos, o bien realizar cambios en la plantilla de la tienda.

## ¿Cómo instalarla?

El CLI la proveemos como una gema en rubygems.org, y requiere de Ruby 2.2
o superior. Afortunadamente, en versiones recientes de macOS, ya viene
instalado Ruby 2.3 (esto lo puedes comprobar corriendo `ruby -v` en un
terminal).

El paso siguiente es asegurarse que estén instaladas las Developer Tools
de Xcode:

 - xcode-select --install

Hecho eso, podemos instalar la gema:

 - sudo gem install bootic_cli

## Para configurarlo:

 - bootic setup (visitar https://auth.bootic.net/dev/cli y agregar credenciales)

## Para usarlo:

- En el terminal, para moverte entre carpetas se escribe 'cd [nombreCarpeta]',
  por ejemplo 'cd proyectos'. si quieres subir un nivel, el comando es 'cd ..'

- Siempre puedes correr el comando 'pwd' para saber la ruta completa de la
  carpeta en la que estás. el comando 'ls' (con ELE) te muestra los archivos
  y carpetas que hay en la ruta que estés.

- Una vez dentro de tu carpeta de trabajo (por ejemplo, /Users/zara/proyectos/superCliente),
  escribe 'bootic themes clone'.

- Con esto se va a descargar una copia de la plantilla de tu tienda (la que
  esté asociada a la cuenta con la que te logueaste antes)

- La plantilla se guardará en una carpeta con el mismo subdominio que la tienda.
  deberías verla si corres 'ls'.

- Luego, una vez dentro de esa carpeta (cd subdominio), puedes correr los
  siguientes comandos:

  - `bootic themes compare` para comparar los cambios entre tu version local y
     la versión que está arriba,
  - `bootic themes pull` para bajar cualquier cambio que haya arriba,
  - `bootic themes push` para subir cualquier cambio que hagas local,
  - `bootic themes sync` para sincronizar los cambios de arriba con los tuyos
     (gana el archivo más reciente en cada lado), y por último,
  - `bootic themes watch` que se queda escuchando cualquier cambio local que
     ocurra, y cuando crees o cambies o elimines un archivo lo sube automáticamente.

El sitio lo sigues viendo "a distancia", pero usando `bootic themes watch` es
casi instantáneo.

Todos estos cambios los puedes hacer directamente sobre el sitio público,
o bien hacerlo sobre el sitio/plantilla de desarrollo, que puedes crear al
momento de correr el comando 'clone'.

Si elijes crear una plantilla de desarrollo todos los cambios que hagas van
a ser sobre un sitio de desarrollo, que puedes ver en `https://url.del.sitio/preview/dev`

Y finalmente, cuando quieras subir los cambios de la plantilla de desarrollo
al sitio público, corres `bootic themes publish`. Esto obviamente no aplica
en caso de que estés trabajo directamente sobre la plantilla pública.

En caso de que inicialmente no hayas creado una plantilla de desarrollo y
luego quieras hacerlo, basta con que elimines la carpeta y corras el comando
de nuevo.
