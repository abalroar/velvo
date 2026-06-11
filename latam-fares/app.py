"""Redirecionador de compatibilidade.

O app foi movido para ../leiloes-intel/app.py. Este arquivo existe apenas para
que deploys antigos do Streamlit Cloud (configurados com main path
'latam-fares/app.py') continuem funcionando após um reboot. Ele executa o
dashboard real, que resolve seus próprios caminhos de dados.
"""
import runpy
from pathlib import Path

target = Path(__file__).resolve().parent.parent / "leiloes-intel" / "app.py"
runpy.run_path(str(target), run_name="__main__")
