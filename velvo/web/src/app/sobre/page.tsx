import SiteNav from "@/components/site-nav";

export const metadata = {
  title: "sobre — velvo",
};

export default function SobrePage() {
  return (
    <>
      <SiteNav active="sobre" />
      <main className="shell">
        <header className="hero" style={{ borderBottom: 0, paddingBottom: 16 }}>
          <span className="label">sobre</span>
          <h1>
            gosto de coisas <em>bonitas</em> e bem-feitas.
          </h1>
        </header>

        <article className="prose">
          <p>
            passo o dia puxando fios entre coisas que não deviam se encontrar: um filósofo
            do acaso, um poeta que trocou os versos pela áfrica, uma música de igreja
            eletrônica, uma série sobre uma funerária, um leilão de móveis numa terça à
            noite. leio por prazer. gosto de saber quem desenhou a cadeira, de quando ela
            é e por onde passou — e de contar isso.
          </p>

          <p>
            a história é parte do valor, com peso maior quando a peça é cara e rara. parte
            dela a gente constrói, e eu conto sabendo disso. o objeto aguenta o olhar de
            perto, e é esse olhar que eu peço de quem compra.
          </p>

          <p>
            desconfio de mim na mesma hora. quando tudo começa a parecer interligado,
            lembro que talvez eu só esteja reparando mais nesses assuntos ultimamente. a
            dúvida é útil: me impede de comprar a própria narrativa antes de testá-la. a
            velvo é, por ora, uma hipótese — testada com calma, peça a peça, com gente em
            quem confio.
          </p>

          <p>
            a aposta tem pé no chão. estética é um dos poucos mercados pouco sujeitos a
            virar obsoletos: o corpo humano não muda de formato tão cedo, e quem tem
            dinheiro e gosto segue querendo coisas belas e escassas — para sentar, usar,
            admirar ou ter.
          </p>

          <blockquote className="pull">
            “servir a deus e ao dinheiro.” é mais ou menos isso que eu tento equilibrar.
          </blockquote>

          <p>
            então é isto: poucas peças, escolhidas a dedo, vendidas pela forma, pelo estado
            e pela história. entrego o que eu mesmo gosto de sentir — a impressão de que o
            objeto tem uma boa história por trás. e tem.
          </p>
        </article>
      </main>
    </>
  );
}
