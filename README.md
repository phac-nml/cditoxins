# phac-nml/cditoxins

## Introduction

**phac-nml/cditoxins** is a bioinformatics pipeline that searches for toxin genes in *Clostridioides difficile* genome assemblies. It mimicks the standard laboratory PCR test for confirmation of *C. difficile* and detection of toxin targets used by ARNI. The following genes are targeted in this pipeline (note both *tcdA* and *tcdC* can have different deletions):

| Gene | Description | Minimum percent identity | Minimum length (bp) | Result |
| :---- | :--- | :---- | :---- | :---- |
| *cdtB* | Binary toxin              | 95 | 528 | POS |
| *tpi*  | Species-specific gene     | 95 | 228 | POS |
| *tcdA* | Toxin A                   | 90 | 100 | 420 bp = POS, 147bp = POS147 |
| *tcdB* | Toxin B                   | 90 | 329 | POS |
| *tcdC* | Regulator of toxins A & B | 90 | 600 | 676 bp = POS, 657 bp = POSDEL, 637 bp = POSDEL18+ |

This pipeline creates a BLASTN database from a set of reference genes, and uses BLASTN to search for target genes in each assembly. The result is then filtered to output a .csv file indicating POS/NEG for each gene target in each assembly. 

See [Leeman *et al.* 2004](https://doi.org/10.1128/jcm.42.12.5710-5714.2004) and [Spigaglia & Mastrantonio *et al.* 2004](https://doi.org/10.1099/jmm.0.45682-0) for more information on the toxin targets and PCR test. 

## Usage

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how to set-up Nextflow. Make sure to [test your setup](https://nf-co.re/docs/usage/introduction#how-to-run-a-pipeline) with `-profile test` before running the workflow on actual data.

First, prepare a samplesheet with your input data that looks as follows:

`samplesheet.csv`:

```csv title="samplesheet.csv"
sample,assembly
SAMPLE1,SAMPLE1_assembly.fasta
SAMPLE2,SAMPLE2_assembly.fasta
SAMPLE3,SAMPLE3_assembly.fasta
```

Each row represents a sample and a genome assembly.

Now, you can run the pipeline using:

```bash
nextflow run phac-nml/cditoxins \
   -profile <docker/singularity/.../institute> \
   --input samplesheet.csv \
   --outdir <OUTDIR>
```

The main parameters are `--input` as defined above and `--output` for specifying the output results directory. You may wish to provide `-profile singularity` to specify the use of singularity containers.

Other parameters (defaults from nf-core) are defined in [nextflow_schema.json](nextflow_schema.json).

> [!WARNING]
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_; see [docs](https://nf-co.re/docs/usage/getting_started/configuration#custom-configuration-files).

A test dataset has been included in this repository. To run with the test profile, please run:

```bash
nextflow run phac-nml/cditoxins -profile singularity,test -outdir results
```

For more information, please see the [usage doc](docs/output.md).

## Output

The main output is the `results.csv` file written to the output directory. It has the following structure:

| sample  | tcdAPCR | tcdBPCR | tcdCPCR | cdtBPCR | tpiPCR |
| :---    | :---    | :----   | :-----  | :---    | :----  |
| SAMPLE1 | POS420  | POS     | POSDEL  | POS     | POS    |
| SAMPLE2 | POS420  | POS     | POS     | NEG     | POS    |
| SAMPLE3 | POS420  | POS     | POS     | NEG     | POS    |

**Note:** *tpi* should always be positive as it is a species-specific gene to confirm *C. difficile* identity. 

In addition, there may be two text files generated in the output directory: 
- `errors.csv` containing a list of sample IDs with empty assembly files and consequently were not searched for toxins with BLASTN
- `nohits.csv` containing a list of sample IDs that had assemblies searched against BLASTN but did not have any hits (negative results)

A JSON file for loading metadata into IRIDA Next is also output by this pipeline. The format of this JSON file is specified in our [Pipeline Standards for the IRIDA Next JSON](https://github.com/phac-nml/pipeline-standards#32-irida-next-json). This JSON file is written directly within the `--outdir` provided to the pipeline with the name `iridanext.output.json.gz` (ex: `[outdir]/iridanext.output.json.gz`).

An example of the what the contents of the IRIDA Next JSON file looks like for this particular pipeline is as follows:

```
{
    "files": {
        "global": [
            {
                "path": "results.csv"
            }
        ],
        "samples": {
            "SAMPLE1": [
                {
                    "path": "blastn/SAMPLE1.txt"
                }
            ],
            "SAMPLE2": [
                {
                    "path": "blastn/SAMPLE2.txt"
                }
            ],
            "SAMPLE3": [
                {
                    "path": "blastn/SAMPLE3.txt"
                }
            ]
        }
    },
    "metadata": {
        "samples": {
            "SAMPLE1": {
                "tcdAPCR": "POS420",
                "tcdBPCR": "POS",
                "tcdCPCR": "POSDEL",
                "cdtBPCR": "POS",
                "tpiPCR": "POS"
            },
            "SAMPLE2": {
                "tcdAPCR": "POS420",
                "tcdBPCR": "POS",
                "tcdCPCR": "POS",
                "cdtBPCR": "NEG",
                "tpiPCR": "POS"
            },
            "SAMPLE3": {
                "tcdAPCR": "POS420",
                "tcdBPCR": "POS",
                "tcdCPCR": "POSDEL",
                "cdtBPCR": "POS",
                "tpiPCR": "POS"
            }
        }
    }
}
```

Within the `files` section of this JSON file, all of the output paths are relative to the `outdir`. Therefore, `"path": "blastn/SAMPLE1.txt"` refers to a file located within `outdir/blastn/SAMPLE1.txt`.

There is also a pipeline execution summary output file provided (specified in the above JSON as `"global": [{"path":"summary/summary.txt.gz"}]`). However, there is no formatting specification for this file.

For more information, please see the [output doc](docs/output.md).

## Credits

This pipeline was developed in consultation with Tim Du. 

Many thanks to Darian Hole for creating the initial version in Galaxy!

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

## Citations

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

This pipeline uses code and infrastructure developed and maintained by the [nf-core](https://nf-co.re) community, reused here under the [MIT license](https://github.com/nf-core/tools/blob/main/LICENSE).

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).

## Legal

Copyright 2025 Government of Canada

Licensed under the MIT License (the "License"); you may not use this work except in compliance with the License. You may obtain a copy of the License at:

https://opensource.org/license/mit/

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.


## Contact

Nicole Lerminiaux: nicole.lerminiaux[at]phac-aspc.gc.ca or nml.arni-rain.lnm[at]phac-aspc.gc.ca