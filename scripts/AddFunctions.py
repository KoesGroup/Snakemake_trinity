import sys

args    = sys.argv
blast   = open(args[1], "r")
couples = {}

for l in blast:
    name = l.split(" ")[0]
    couples[name] = l.split("\t")[-1]
blast.close()

fa      = open(args[2], "r")
uitfile = open(args[3], "w")

for l in fa:
    if l.startswith(">"):
        name = l.split(" ")[0].lstrip(">")
        if name in couples:
            regel = l.split(" ")[0] + " " + couples[name]
        else :
            regel = l.split(" ")[0] + " no petunia homolog found"
    else:
        regel = l
    uitfile.write(regel)
uitfile.close()
fa.close()