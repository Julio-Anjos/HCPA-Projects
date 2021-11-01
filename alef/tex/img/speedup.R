library(ggplot2)
df <- read.csv("resumo_speedup.csv")
g <- ggplot(df) + geom_point(aes(x=nucleos, y=minutos)) + geom_text(aes(x=nucleos - 0.25, y=minutos - 45, label=speedup)) + geom_line(aes(x=nucleos, y=minutos, linetype=as.factor(entrada))) + theme_bw(base_size=14) + xlab("Núcleos") + ylab("Minutos") + guides(linetype=guide_legend(title="Entradas")) + theme(legend.position="bottom")
ggsave("speedup.png")
