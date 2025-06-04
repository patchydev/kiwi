\documentclass[11pt]{article}
\usepackage[utf8]{inputenc}
\usepackage{listings}
\usepackage{xcolor}
\usepackage{geometry}

\geometry{margin=1in}

\lstdefinelanguage{Kiwi}{
keywords={let, fn, return, int, string, bool, float},
keywordstyle=\color{blue}\bfseries,
basicstyle=\ttfamily\small,
breaklines=true,
showstringspaces=false
}

\title{Kiwi Grammar}
\date{}
\begin{document}

\maketitle

\section{Grammar}

\begin{verbatim}
program := statement\*

statement := variable_declaration
| function_declaration  
 | return_statement

variable_declaration := "let" identifier ":" type "=" expression ";"

function_declaration := "fn" identifier "(" parameter_list? ")" "->" type block
parameter_list := parameter ("," parameter)_
parameter := identifier ":" type
block := "{" statement_ "}"

return_statement := "return" expression ";"

expression := additive_expression
additive_expression := multiplicative_expression (("+" | "-") multiplicative_expression)_
multiplicative_expression := primary_expression (("_" | "/") primary_expression)\*
primary_expression := number | identifier | "(" expression ")"

type := "i32" | "TODO"

identifier := letter (letter | digit)\*
number := digit+
\end{verbatim}

\section{Examples}

\begin{lstlisting}[language=Kiwi]
let x: int = 2;
let y: int = x + 4;
return x;
\end{lstlisting}

\begin{lstlisting}[language=Kiwi]
fn add(a: int, b: int) -> int {
return a + b;
}
\end{lstlisting}

\section{Implementation Status}

\textbf{Working:}

\begin{itemize}
\item[$\checkmark$] Basic variable declarations (no types yet)
\item[$\checkmark$] Arithmetic expressions (+, -, \*, /)
\item[$\checkmark$] Return statements
\item[$\checkmark$] Variable references
\end{itemize}

\textbf{TODO:}

\begin{itemize}
\item[$\square$] Type annotations
\item[$\square$] Function declarations
\item[$\square$] Function calls
\end{itemize}

\end{document}
