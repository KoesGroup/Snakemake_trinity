#define configfilecws
configfile: "configs/configs.yaml"

# fetch URL,s to transcriptome gtf and genome and transcriptome multi fasta's from configfile
transcriptome_fasta_URL = config["refs"]["transcriptomeFas"]

# create lists containing samplenames and conditions from the file: data/sampls.txt
import pandas as pd
sampleTable = pd.read_table(config["units"])
SAMPLES     = list(sampleTable["sample"])
fqs         = dict(zip(list(sampleTable["sample"]), list(sampleTable["fq"])))

rule all:
    input:
        expand("trimmed/{sample}_qc.fq", sample=SAMPLES),
        "trinity.Trinity.fasta",
        "trinity.Trinity.fasta.gene_trans_map",
        "transcriptome_blast.txt"
    message:
        "Job done!"


# trim and quality filter of the reads
rule trimmomatic:
    input:
        fq1   = lambda wildcards: fqs[wildcards.SAMPLES],
    output:
        "trimmed/{SAMPLES}_qc.fq",
#    message: "trimming reads"
#        "logs/trimmomatic/{SAMPLES}.log"
    params:
        adapters                = str(config["adapters"]),
        seedMisMatches          = str(config['trimmomatic']['seedMisMatches']),
        palindromeClipTreshold  = str(config['trimmomatic']['palindromeClipTreshold']),
        simpleClipThreshhold    = str(config['trimmomatic']['simpleClipThreshold']),
        LeadMinTrimQual         = str(config['trimmomatic']['LeadMinTrimQual']),
        TrailMinTrimQual        = str(config['trimmomatic']['TrailMinTrimQual']),
        windowSize              = str(config['trimmomatic']['windowSize']),
        avgMinQual              = str(config['trimmomatic']['avgMinQual']),
        minReadLen              = str(config['trimmomatic']['minReadLength']),
        phred                   = str(config["trimmomatic"]["phred"])
    threads: 1
    shell:
        "trimmomatic SE {params.phred} -threads {threads} "
        "{input.fq1} "
        "{output} "
        "ILLUMINACLIP:{params.adapters}:{params.seedMisMatches}:{params.palindromeClipTreshold}:{params.simpleClipThreshhold} "
        "LEADING:{params.LeadMinTrimQual} "
        "TRAILING:{params.TrailMinTrimQual} "
        "SLIDINGWINDOW:{params.windowSize}:{params.avgMinQual} "
        "MINLEN:{params.minReadLen}" #" 2>{log}"

#assemble transcriptome
rule Trinity:
    input:
        expand("trimmed/{sample}_qc.fq", sample=SAMPLES)
    output:
        "trinity.Trinity.fasta",
        "trinity.Trinity.fasta.gene_trans_map"
    conda:
        "envs/trinity.yaml"
    params:
        fqs         = lambda wildcards: ",".join(expand("trimmed/{sample}_qc.fq", sample=SAMPLES)),
        cpu         = str(config['trinity']['cpu']),
        libType     = str(config['trinity']['libType']),
        seqType     = str(config['trinity']['seqType']),
        minLenght   = str(config['trinity']['minLength']),
        maxMemory   = str(config['trinity']['maxMemory']),
        outDir      = str(config['trinity']['outDir'])
    shell:
        "Trinity "
        "--CPU {params.cpu} "
        "--seqType {params.seqType} "
        "--max_memory {params.maxMemory} "
        "--SS_lib_type {params.libType} "
        "--single {params.fqs} "
        "--output {params.outDir} "
        "--full_cleanup"

# download transcriptome fasta's with the use of the URL
rule get_transcriptome_fasta:
    output:
        "ref_transcriptome/ref_transcriptome.fasta"
    message:"downloading required transcriptome fasta file"
    shell: "wget -O {output} {transcriptome_fasta_URL}"

# create transcriptome index, for blasting
rule get_ref_transcriptome_index:
    input:
        "ref_transcriptome/ref_transcriptome.fasta"
    output:
        ["ref_transcriptome/ref_transcriptome.fasta." + i for i in ("psq", "phr", "pin")]
    conda:
        "envs/blast.yaml"
    shell:
        "makeblastdb -in {input} -dbtype prot"

#run blast to get list of function to DeNovo transcriptome
rule blast_for_funtions:
    input:
        newTct     = "trinity.Trinity.fasta",
        refTct     = "ref_transcriptome/ref_transcriptome.fasta",
        indexFiles = ["ref_transcriptome/ref_transcriptome.fasta." + i for i in ("psq", "phr", "pin")]
    output:
        "transcriptome_blast.txt"
    params:
        evalue     = str(config['blast']['evalue']),     # 1e-10
        outFmt     = str(config['blast']['outFmt']),     # 6 qseqid qlen slen evalue salltitles
        numThreads = str(config['blast']['numThreads']),
        maxTargets = str(config['blast']['maxTargets']) # 1
    conda:
        "envs/blast.yaml"
    shell:
        "blastx "
        "-query {input.newTct} "
        "-db {input.refTct} "
        "-outfmt \"{params.outFmt}\" "
        "-evalue {params.evalue} "
        "-out {output} "
        "-num_threads {params.numThreads} "
        "-max_target_seqs {params.maxTargets}"

# add putative functions to deNove trabscriptome fasta file
rule functions_to_transcriptome:
    input:
        blastResult = "transcriptome_blast.txt",
        DeNovo      = "trinity.Trinity.fasta"
    output:
        "Cpyg.fasta"
    shell:
        "python AddFunctions.py {input.blastResult} {input.DeNovo} {output}"
