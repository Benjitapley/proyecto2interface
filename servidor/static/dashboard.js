/* Consulta los registros guardados; la recepción serial sigue siendo de Lazarus. */
(() => {
  const panel = document.getElementById('panel');
  const grafica = document.getElementById('grafica');
  const baseGrafica = grafica.getAttribute('src');
  const estado = document.getElementById('estado-actualizacion');
  let imagenActual = null;
  const campos = ['id', 'fecha_hora', 'mp01', 'mp02', 'mp03',
    'hi01', 'hi02', 'hi03', 'hi04', 'hi05', 'hi06', 'te', 'hr'];

  function mostrarRegistros(registros) {
    const filas = document.createDocumentFragment();
    for (const registro of registros) {
      const fila = document.createElement('tr');
      const celda = document.createElement('td');
      const enlace = document.createElement('a');
      enlace.href = panel.dataset.registroUrl.replace(/0$/, registro.registro_id);
      enlace.textContent = '#' + registro.registro_id;
      celda.append(enlace);
      fila.append(celda);
      for (const campo of campos) {
        const dato = document.createElement('td');
        dato.textContent = registro[campo];
        fila.append(dato);
      }
      filas.append(fila);
    }
    if (!registros.length) {
      const fila = document.createElement('tr');
      const celda = document.createElement('td');
      celda.colSpan = 14;
      celda.className = 'empty';
      celda.textContent = 'Sin datos de esta UMA. Conecta el COM en Lazarus y activa «Enviar UMA seleccionada a Flask».';
      fila.append(celda);
      filas.append(fila);
    }
    document.getElementById('registros').replaceChildren(filas);
  }

  async function actualizar() {
    const control = new AbortController();
    const espera = setTimeout(() => control.abort(), 4000);
    try {
      const respuesta = await fetch(panel.dataset.api, { cache: 'no-store', signal: control.signal });
      if (!respuesta.ok) throw new Error('HTTP ' + respuesta.status);
      const datos = await respuesta.json();
      const imagen = await fetch(baseGrafica + '&t=' + Date.now(), { cache: 'no-store', signal: control.signal });
      if (!imagen.ok) throw new Error('Gráfica HTTP ' + imagen.status);
      const nuevaImagen = URL.createObjectURL(await imagen.blob());
      const ultima = datos.registros.at(-1);
      mostrarRegistros(datos.registros);
      document.getElementById('total').textContent = datos.total;
      document.getElementById('devueltos').textContent = datos.devueltos;
      document.getElementById('temperatura').textContent = ultima?.te ?? '—';
      document.getElementById('humedad').textContent = ultima?.hr ?? '—';
      document.getElementById('pm25').textContent = ultima?.mp02 ?? '—';
      grafica.src = nuevaImagen;
      if (imagenActual) URL.revokeObjectURL(imagenActual);
      imagenActual = nuevaImagen;
      estado.textContent = 'Datos actualizados a las ' + new Date().toLocaleTimeString('es-CL') + '. Próxima consulta en 5 segundos.';
      estado.classList.remove('error');
    } catch (error) {
      estado.textContent = 'No se pudo actualizar. Se conserva la última consulta; revisa Flask. Se reintentará en 5 segundos.';
      estado.classList.add('error');
    } finally {
      clearTimeout(espera);
      // Esperar al final de cada petición evita consultas superpuestas si Flask tarda.
      setTimeout(actualizar, 5000);
    }
  }

  grafica.addEventListener('error', () => {
    estado.textContent = 'No se pudo cargar la gráfica. Se reintentará en la próxima actualización.';
    estado.classList.add('error');
  });
  setTimeout(actualizar, 5000);
})();
