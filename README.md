# gym_member — App de miembros (fase 1)

Login, registro, vinculación con código de 6 caracteres y tarjeta de suscripción.

## Puesta en marcha

```bash
flutter create . --org com.tugimnasio --platforms android,ios,linux
flutter pub get
```

`flutter create .` genera las carpetas android/ios/linux sin tocar `lib/` ni `pubspec.yaml`.

Crea `env.json` en la raíz (y añádelo a `.gitignore`):

```json
{
  "SUPABASE_URL": "https://tdtdyxbwpiizidsmlaij.supabase.co",
  "SUPABASE_ANON_KEY": "eyJ..."
}
```

La anon key está en Supabase → Project Settings → API. Nunca uses la service_role key en la app.

```bash
flutter run -d linux --dart-define-from-file=env.json
```

## Probar el flujo completo

1. SQL Editor — genera un código para un miembro existente (como superusuario
   no pasa el check de staff, así que usa este update directo):

   ```sql
   update members
      set link_code = 'TEST01', link_code_expires_at = now() + interval '1 day'
    where id = '<uuid del miembro>' and user_id is null;
   ```
2. En la app: Regístrate → introduce `TEST01` → debe aparecer la tarjeta.
3. Comprueba que el nuevo usuario quedó como `member`:
   `select email, role from profiles order by created_at desc limit 3;`

## Estructura

```
lib/
  core/                 env, mensajes de error
  features/
    auth/               login, registro, sesión
    member/             ficha del miembro + vinculación por código
    subscription/       tarjeta de membresía e historial
```
