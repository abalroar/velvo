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
            o tempo gasta quase tudo. <em>quase.</em>
          </h1>
        </header>

        <article className="prose">
          <p>
            a gente passa pelo mundo como visitante. o tempo desfaz cidades, modas,
            rotinas — e a maior parte do que a gente jura conhecer. mas alguns objetos
            atravessam décadas inteiras: um vidro soprado, um bronze, uma porcelana que
            sobreviveu a mudanças, heranças e esquecimentos. é atrás desses sobreviventes
            que a velvo existe.
          </p>

          <p>
            curar é só uma forma de prestar atenção. olhar duas vezes onde o mercado vê um
            lote — e enxergar um objeto: com estado, com forma, com uma história que ele
            carrega sem precisar contar. a gente garimpa em leilões pelo brasil e devolve
            essas peças como o que elas sempre foram — coisas para usar, admirar ou
            simplesmente ter.
          </p>

          <blockquote className="pull">uma a uma. é assim que a gente escolhe.</blockquote>

          <p>
            não trabalhamos com volume. cada peça é escolhida uma a uma — por isso a
            vitrine é curta e muda devagar. ela é feita de decisões, não de estoque. o que
            não passa pela mesa não chega até você.
          </p>

          <p>
            todo objeto bom carrega uma pergunta sobre espaço: onde ele cabe? numa casa,
            numa mesa, numa vida que já está cheia. a gente prefere as peças que respondem
            isso sozinhas — que chegam e parecem ter estado ali o tempo todo.
          </p>

          <p>
            a aposta é simples, quase teimosa: a tecnologia muda, as modas passam, mas o
            desejo por beleza escassa não. o formato de uma boa cadeira não envelhece.
            enquanto isso for verdade, vale a pena escolher devagar — e deixar que a
            estética seja a parte do mundo que insiste em durar.
          </p>
        </article>
      </main>
    </>
  );
}
