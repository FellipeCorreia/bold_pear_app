"""Concede (ou remove) acesso ao painel NASA sem abrir o SQL Editor.

Usa a Management API do Supabase com um token pessoal, lido da variável de
ambiente SUPABASE_ACCESS_TOKEN (crie em https://supabase.com/dashboard/account/tokens).
O token nunca vai para o repositório.

    python scripts/grant_admin.py admin.nasa@nasa.com outra@pessoa.com
    python scripts/grant_admin.py --revoke outra@pessoa.com
    python scripts/grant_admin.py --list

As contas precisam existir (cadastro no app ou Authentication → Users).
"""

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request

PROJECT_REF = os.environ.get("SUPABASE_PROJECT_REF", "omhfegwzorvrpscdftvg")
API = f"https://api.supabase.com/v1/projects/{PROJECT_REF}/database/query"
EMAIL = re.compile(r"^[^@\s',;]+@[^@\s',;]+\.[^@\s',;]+$")

LIST_SQL = """
select u.email, a.created_at
from public.admins a join auth.users u on u.id = a.user_id
order by a.created_at;
"""


def run(sql: str, token: str):
    req = urllib.request.Request(
        API,
        data=json.dumps({"query": sql}).encode(),
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "User-Agent": "bold-pear-admin-script",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read() or "[]")
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace")[:400]
        sys.exit(f"Erro {e.code} da API do Supabase: {body}")


def sql_list(emails):
    # Os e-mails já passaram pela regex (sem aspas, vírgulas ou espaços).
    return ", ".join(f"'{e.lower()}'" for e in emails)


def main():
    # Console do Windows (cp1252) não imprime acentos/setas sem isto.
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("emails", nargs="*")
    p.add_argument("--revoke", action="store_true", help="remove o acesso em vez de conceder")
    p.add_argument("--list", action="store_true", help="só lista quem é admin")
    args = p.parse_args()

    token = os.environ.get("SUPABASE_ACCESS_TOKEN")
    if not token:
        sys.exit("Defina SUPABASE_ACCESS_TOKEN (token pessoal do Supabase) antes de rodar.")

    bad = [e for e in args.emails if not EMAIL.match(e)]
    if bad:
        sys.exit(f"E-mail inválido: {', '.join(bad)}")
    if not args.emails and not args.list:
        p.error("informe pelo menos um e-mail (ou use --list)")

    if args.emails:
        found = run(f"select lower(email) as email from auth.users where lower(email) in ({sql_list(args.emails)});", token)
        existing = {r["email"] for r in found}
        missing = [e for e in args.emails if e.lower() not in existing]
        for e in missing:
            print(f"! {e}: conta não encontrada (cadastre antes)")
        ok = [e for e in args.emails if e.lower() in existing]
        if ok:
            if args.revoke:
                run(f"delete from public.admins where user_id in "
                    f"(select id from auth.users where lower(email) in ({sql_list(ok)}));", token)
            else:
                run(f"insert into public.admins (user_id) select id from auth.users "
                    f"where lower(email) in ({sql_list(ok)}) on conflict (user_id) do nothing;", token)
            for e in ok:
                print(f"{'-' if args.revoke else '+'} {e}")

    print("\nAdmins atuais:")
    rows = run(LIST_SQL, token)
    for r in rows:
        print(f"  {r['email']}  (desde {r['created_at']})")
    if not rows:
        print("  (nenhum)")


if __name__ == "__main__":
    main()
