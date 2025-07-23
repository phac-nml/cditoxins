#!/usr/bin/env python3

# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
#
# PURPOSE: 
# This script takes multiple *txt files output by blastn and 
# filters the results to output a POS/NEG value table for 
# each of the toxin gene targets for each sample
# AUTHOR: Nicole Lerminiaux <nicole.lerminiaux@phac-aspc.gc.ca>
#
# COMMAND LINE USAGE:
#
# filtering_blast.py samplesheet.csv
#
# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

import os
import glob
import pandas as pd
import sys

# import samplesheet
sample_file = str(sys.argv[1])
nohits_file = str(sys.argv[2])

# import *.txt files and skip empty files
files = glob.glob(os.path.join("*.txt"))
data = []

for i in range(0,len(files)):
    try:
        temp = pd.read_csv(files[i], sep="\t", header=None)
        # add filename as a column
        temp['filename'] = os.path.basename(files[i])
        data.append(temp)
    except pd.errors.EmptyDataError:
        continue

# initialize empty list for output data 
output_data = []

# loop through each sample
for df in data:
    # rename columns
    df.columns = ["qseqid","sseqid","pident","length","mismatch","gapopen","qstart","qend","sstart","send","evalue","bitscore","filename"]
    # subset relevant columns
    subset = df[["filename","sseqid","pident","length"]]
    # sort on percent identity
    sorted = subset.sort_values("pident", ascending=False)
    # keep top hits for each gene - order is preserved
    top = sorted.drop_duplicates(subset=["filename","sseqid"])
    # get sample name
    sample_ID = str(top['filename'].values[0]).removesuffix('.txt')
    # get smaller dfs for each gene based on percent ID and length 
    tcdB = top[(top["sseqid"].str.contains("tcdB")) & (top["pident"] >= 90) & (top["length"] >= 329) ]
    cdtB = top[(top["sseqid"].str.contains("cdt_B")) & (top["pident"] >= 95) & (top["length"] >= 528) ]
    tpi = top[(top["sseqid"].str.contains("tpi")) & (top["pident"] >= 95) & (top["length"] >= 228) ]
    tcdA = top[(top["sseqid"].str.contains("tcdA")) & (top["pident"] >= 90) & (top["length"] >= 100)]
    tcdC = top[(top["sseqid"].str.contains("tcdC")) & (top["pident"] >= 90) & (top["length"] >= 600)]
    # if there is tcdB hit, print pos
    if not tcdB.empty:
        output_data.append([sample_ID, "tcdBPCR", "POS"])
    else:
        output_data.append([sample_ID, "tcdBPCR", "NEG"])
    # if there is cdtB hit, print pos
    if not cdtB.empty:
        output_data.append([sample_ID, "cdtBPCR", "POS"])
    else:
        output_data.append([sample_ID, "cdtBPCR", "NEG"])
    # if there is tpi hit, print pos
    if not tpi.empty:
        output_data.append([sample_ID, "tpiPCR", "POS"])
    else:
        output_data.append([sample_ID, "tpiPCR", "NEG"])
    # if there is tcdA hit, take the top hit based on sequence ID, then print which pos
    if not tcdA.empty:
        if "420bp" in tcdA.drop_duplicates(subset=["filename"])["sseqid"].values[0]:
            output_data.append([sample_ID, "tcdAPCR", "POS420"])
        elif "147bp" in tcdA.drop_duplicates(subset=["filename"])["sseqid"].values[0]:
            output_data.append([sample_ID, "tcdAPCR", "POS147"])
    else:
        output_data.append([sample_ID, "tcdAPCR", "NEG"])
    # if there is tcdA hit, take the top hit based on sequence ID, then print which pos
    if not tcdC.empty:
        if "676bp" in tcdC.drop_duplicates(subset=["filename"])["sseqid"].values[0]:
            output_data.append([sample_ID, "tcdCPCR", "POS"]) 
        elif "657bp" in tcdC.drop_duplicates(subset=["filename"])["sseqid"].values[0]:
            output_data.append([sample_ID, "tcdCPCR", "POSDEL"]) 
        elif "637bp" in tcdC.drop_duplicates(subset=["filename"])["sseqid"].values[0]:
            output_data.append([sample_ID, "tcdCPCR", "POSDEL18+"]) 
    else:
        output_data.append([sample_ID, "tcdCPCR", "NEG"])

# concatenate all data together
df = pd.DataFrame(output_data, columns = ["sample", "PCR", "result"])
df_pivoted = df.pivot(index="sample", columns="PCR", values="result")
df_pivoted = df_pivoted[["tcdAPCR", "tcdBPCR", "tcdCPCR", "cdtBPCR", "tpiPCR"]]

# add to sample sheet - this will include samples with no blast hits
sample_list = pd.read_csv(sample_file, header=0)
samples = sample_list.loc[:,('sample')]

# import nohits and add to dataframe
try:
    nohits = pd.read_csv(nohits_file, names=["sample", "tcdAPCR", "tcdBPCR", "tcdCPCR", "cdtBPCR", "tpiPCR"]).fillna("NEG").set_index("sample")
    concat_nohits = pd.concat([df_pivoted, nohits])
except FileNotFoundError:
    concat_nohits = df_pivoted
    
# join to samplesheet and NaN will fill in those with empty assemblies 
joined = pd.merge(samples, concat_nohits, on="sample", how = "left")

# write output file
joined.to_csv(("results.csv"), sep=",", index=False)
