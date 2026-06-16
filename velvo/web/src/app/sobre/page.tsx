import SiteNav from "@/components/site-nav";

export const metadata = {
  title: "sobre — velvo",
};

export default function SobrePage() {
  return (
    <>
      <SiteNav active="sobre" />
      <main className="shell">
        <header className="hero" style={{ borderBottom: 0, paddingBottom: 12 }}>
          <span className="label">sobre</span>
          <h1>o tempo carrega quase tudo.</h1>
        </header>

        <div className="lead">
          <p>
            a gente passa pelo mundo, enquanto objetos são amuletos do tempo: atravessam
            décadas, intempéries, entre heranças e novas estórias.
          </p>
          <p>a gente presta atenção e se esforça pra enxergar: peça a peça. uma a uma.</p>
        </div>

        <article className="prose">
          <p>
            passo o dia puxando fios entre coisas que não deviam se encontrar: um filósofo
            do acaso, um poeta que trocou os versos pela áfrica, uma música de igreja
            eletrônica, um leilão de móveis numa terça à noite. gosto de saber quem
            desenhou a cadeira, de quando ela é e por onde passou — e de contar isso. a
            história é parte do valor, com peso maior quando a peça é cara e rara. parte
            dela a gente constrói, e eu conto sabendo disso.
          </p>

          <p>
            desconfio de mim na mesma hora. quando tudo começa a parecer interligado,
            lembro que talvez eu só esteja reparando mais nesses assuntos ultimamente. a
            dúvida me impede de comprar a própria narrativa antes de testá-la. isto é, por
            ora, uma hipótese — testada com calma, peça a peça, com gente em quem confio.
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
            poucas peças, escolhidas a dedo, vendidas pela forma, pelo estado e pela
            estória. entrego o que eu mesmo gosto de sentir — a impressão de que o objeto
            tem uma boa história por trás. e tem.
          </p>
        </article>
      </main>
    </>
  );
}
